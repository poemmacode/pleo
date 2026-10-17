module Crawling
  # robots.txt per host, fetched on first use and stored on the crawl (crawl_hosts).
  module HostRegistry
    module_function

    def fetch(crawl, url)
      uri = URI.parse(url)
      CrawlHost.find_by(crawl:, host: uri.host) || load(crawl, uri)
    end

    def load(crawl, uri)
      origin = "#{uri.scheme}://#{uri.host}#{":#{uri.port}" unless uri.port == uri.default_port}"
      Crawling.rate_limiter.acquire(uri.host, rps: crawl.current_rps, max_wait: 60)
      client = SafeHttp::Client.new(user_agent: Crawling.user_agent(crawl.crawl_config.device),
                                    max_bytes: SafeHttp::Robots::Parser::MAX_BYTES)
      result = SafeHttp::Robots::Fetcher.new(client:).fetch(origin)

      CrawlHost.create_or_find_by!(crawl:, host: uri.host) do |host|
        host.robots_outcome = result.outcome.to_s
        host.robots_status = result.status
        host.robots_txt = result.body
        host.crawl_delay = result.crawl_delay
        host.sitemaps = result.sitemaps
        host.fetched_at = Time.current
      end
    end
  end
end
