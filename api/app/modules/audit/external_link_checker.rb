module Audit
  # Checks external link targets (docs/03 §5 links.external_broken): HEAD, falling back to a small
  # GET when HEAD is refused; one request per second per host, robots.txt respected, at most
  # MAX_URLS per crawl. Runs a few threads because targets are spread over many hosts.
  class ExternalLinkChecker
    MAX_URLS = 1_000
    THREADS = 6
    HEAD_REFUSED = [ 403, 405, 501 ].freeze

    def initialize(crawl, limiter: Crawling.rate_limiter)
      @crawl = crawl
      @limiter = limiter
      @robots = {}
      @robots_lock = Mutex.new
    end

    def call
      urls = Link.where(crawl_id: @crawl.id, internal: false).where("to_url ~* '^https?://'").distinct.limit(MAX_URLS).pluck(:to_url)
      queue = Queue.new
      urls.each { queue << _1 }
      results = Queue.new
      client = SafeHttp::Client.new(user_agent: Crawling.user_agent(@crawl.crawl_config.device), max_bytes: 1024, total_timeout: 15)

      Array.new([ THREADS, urls.size ].min) do
        Thread.new do
          while (url = queue.pop(true) rescue nil)
            results << check(client, url)
          end
        end
      end.each(&:join)

      rows = Array.new(results.size) { results.pop }.map { _1.merge(crawl_id: @crawl.id, url_hash: CrawlUrl.hash_url(_1[:url]), checked_at: Time.current) }
      ExternalLinkCheck.upsert_all(rows, unique_by: %i[crawl_id url_hash]) if rows.any?
      rows.size
    end

    private
      def check(client, url)
        host = URI.parse(url).host
        return { url:, status_code: nil, error: "robots" } unless robots_for(client, url).allowed?(url)

        @limiter.acquire(host, rps: 1, max_wait: 120)
        response = client.head(url)
        if HEAD_REFUSED.include?(response.status)
          @limiter.acquire(host, rps: 1, max_wait: 120)
          response = client.get(url, headers: { "Range" => "bytes=0-0" })
          response = response.with(status: 200) if response.status == 206
        end
        { url:, status_code: response.status, error: nil }
      rescue SafeHttp::Errors::Base, URI::Error => e
        { url:, status_code: nil, error: e.class.name.demodulize.underscore.first(50) }
      end

      def robots_for(client, url)
        uri = URI.parse(url)
        origin = "#{uri.scheme}://#{uri.host}#{":#{uri.port}" unless uri.port == uri.default_port}"
        @robots_lock.synchronize { @robots[origin] } || begin
          policy = SafeHttp::Robots::Fetcher.new(client:).fetch(origin).policy
          @robots_lock.synchronize { @robots[origin] = policy }
        rescue SafeHttp::Errors::UnsafeTarget, SafeHttp::Errors::InvalidUrl
          @robots_lock.synchronize { @robots[origin] = SafeHttp::Robots::Policy.disallow_all }
        end
      end
  end
end
