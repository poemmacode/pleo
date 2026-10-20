require "net/http"

module SafeHttp
  # HTTP client for URLs supplied by users or discovered while crawling.
  #
  # Per request and per redirect hop: validate the URL, resolve every A/AAAA record ourselves,
  # reject the target if any address is blocked, then connect to that validated IP (Net::HTTP#ipaddr)
  # while sending the original Host header and SNI. A second, malicious DNS answer (rebinding)
  # is never consulted. Env proxies are ignored and redirects are followed manually.
  class Client
    REDIRECT_STATUSES = [ 301, 302, 303, 307, 308 ].freeze
    DEFAULT_MAX_BYTES = 5 * 1024 * 1024

    def initialize(resolver: SafeHttp.config.resolver, user_agent: SafeHttp.config.user_agent, open_timeout: 5,
                   read_timeout: 15, total_timeout: 30, max_bytes: DEFAULT_MAX_BYTES, max_redirects: 10)
      @resolver = resolver
      @user_agent = user_agent
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @total_timeout = total_timeout
      @max_bytes = max_bytes
      @max_redirects = max_redirects
    end

    def get(url, follow_redirects: true, headers: {})
      perform(Net::HTTP::Get, url, follow_redirects:, headers:)
    end

    def head(url, follow_redirects: true, headers: {})
      perform(Net::HTTP::Head, url, follow_redirects:, headers:)
    end

    # Validates and resolves without connecting; used to reject unsafe targets at input time.
    def preflight!(url)
      target = UrlValidator.validate!(url)
      resolve!(target)
      target
    end

    private
      def perform(request_class, url, follow_redirects:, headers:)
        started = monotonic
        deadline = started + @total_timeout
        chain = []

        loop do
          target = UrlValidator.validate!(url)
          ip = resolve!(target)
          status, response_headers, body, truncated = request_once(request_class, target, ip, headers, deadline)
          location = response_headers["location"]&.first

          if follow_redirects && REDIRECT_STATUSES.include?(status) && location
            raise Errors::TooManyRedirects, "more than #{@max_redirects} redirects" if chain.size >= @max_redirects

            chain << { url:, status: }
            url = resolve_location(target.uri, location)
            next
          end

          return Response.new(url:, status:, headers: response_headers, body:, ip: ip.to_s, redirect_chain: chain,
                              truncated:, elapsed_ms: ((monotonic - started) * 1000).round)
        end
      end

      def resolve!(target)
        return target.literal_ip if target.literal_ip

        addresses = @resolver.addresses(target.host)
        raise Errors::Resolution, "#{target.host} has no A/AAAA records" if addresses.empty?

        # Reject if *any* record is blocked, so a mixed answer cannot be used to reach an internal address.
        blocked = addresses.find { IpPolicy.blocked?(_1) }
        raise Errors::UnsafeTarget, "#{target.host} resolves to a blocked address (#{blocked})" if blocked

        addresses.find(&:ipv4?) || addresses.first
      end

      def request_once(request_class, target, ip, extra_headers, deadline)
        http = Net::HTTP.new(target.host, target.port, nil)
        http.ipaddr = ip.to_s
        http.use_ssl = target.uri.scheme == "https"
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.max_retries = 0
        remaining = deadline - monotonic
        raise Errors::Timeout, "total time limit exceeded" if remaining <= 0

        http.open_timeout = [ @open_timeout, remaining ].min
        http.read_timeout = [ @read_timeout, remaining ].min
        http.write_timeout = [ @open_timeout, remaining ].min

        request = request_class.new(target.uri.request_uri)
        request["User-Agent"] = @user_agent
        request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        # Setting this header disables Net::HTTP's automatic decoding; BodyReader inflates with a size cap.
        request["Accept-Encoding"] = "gzip, deflate"
        extra_headers.each { |name, value| request[name] = value }

        status = response_headers = reader = nil
        truncated = false

        begin
          http.start do
            http.request(request) do |response|
              status = response.code.to_i
              response_headers = response.to_hash
              reader = BodyReader.new(response["content-encoding"], @max_bytes)
              response.read_body do |chunk|
                raise Errors::Timeout, "total time limit exceeded" if monotonic > deadline

                reader << chunk
              end
              reader.finish
            end
          end
        rescue BodyReader::LimitReached
          # Raised from inside read_body: Net::HTTP drops the connection, which is what we want.
          truncated = true
        end

        [ status, response_headers, reader.body, truncated ]
      rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout => e
        raise Errors::Timeout, e.class.name.demodulize
      rescue OpenSSL::SSL::SSLError => e
        raise Errors::Tls, e.message
      rescue SocketError, SystemCallError, IOError, EOFError, Zlib::Error, Net::HTTPBadResponse => e
        raise Errors::Connection, "#{e.class.name}: #{e.message}"
      end

      def resolve_location(base, location)
        URI.join(base.to_s, location).to_s
      rescue URI::Error
        raise Errors::InvalidUrl, "invalid Location header"
      end

      def monotonic
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
  end
end
