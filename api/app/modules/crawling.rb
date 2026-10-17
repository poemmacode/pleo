module Crawling
  SITEMAP_MAX_BYTES = 50 * 1024 * 1024 # sitemaps.org limit for one (uncompressed) file

  class << self
    attr_writer :rate_limiter

    def rate_limiter
      @rate_limiter ||= SafeHttp::HostRateLimiter.new
    end

    # The bot token stays in the mobile UA so robots.txt rules for SEOPlatformBot still apply.
    def user_agent(device)
      base = SafeHttp.config.user_agent
      device == "mobile" ? base.sub("(+", "(Linux; Android 14; Mobile; +") : base
    end

    def http_client(crawl, max_bytes: SafeHttp::Client::DEFAULT_MAX_BYTES)
      SafeHttp::Client.new(user_agent: user_agent(crawl.crawl_config.device), max_bytes:)
    end
  end
end
