require "ipaddr"

module SafeHttp
  # Static checks on a URL before any DNS lookup: scheme, credentials, port and host form.
  module UrlValidator
    Target = Data.define(:uri, :host, :port, :literal_ip)

    SCHEMES = %w[http https].freeze

    module_function

    def validate!(url)
      url = url.to_s
      raise Errors::InvalidUrl, "the URL contains disallowed characters" if url.match?(/[\x00-\x20\x7f]/) || !url.ascii_only?

      uri = URI.parse(url)
      raise Errors::UnsafeTarget, "only http and https are allowed" unless SCHEMES.include?(uri.scheme&.downcase)
      raise Errors::UnsafeTarget, "the URL must not include credentials" if uri.userinfo
      raise Errors::InvalidUrl, "the URL has no host" if uri.hostname.blank?
      raise Errors::UnsafeTarget, "port #{uri.port} is not allowed" unless SafeHttp.config.allowed_ports.include?(uri.port)

      host = uri.hostname.downcase.delete_suffix(".")
      Target.new(uri:, host:, port: uri.port, literal_ip: check_host!(host))
    rescue URI::InvalidURIError
      raise Errors::InvalidUrl, "malformed URL"
    end

    # Returns the IP when the host is an IP literal, nil for a DNS name.
    def check_host!(host)
      if (ip = parse_ip(host))
        raise Errors::UnsafeTarget, "address #{ip} is blocked" if IpPolicy.blocked?(ip)

        ip
      elsif HostPolicy.numeric_host?(host)
        raise Errors::UnsafeTarget, "ambiguous numeric host"
      elsif HostPolicy.blocked_hostname?(host)
        raise Errors::UnsafeTarget, "internal or reserved host"
      end
    end

    def parse_ip(host)
      return unless host.match?(Resolv::IPv4::Regex) || host.match?(Resolv::IPv6::Regex)

      IPAddr.new(host)
    end
  end
end
