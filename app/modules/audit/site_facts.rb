module Audit
  # Site-level facts for the GEO / AI search checks: which AI crawlers robots.txt blocks, and llms.txt.
  module SiteFacts
    AI_BOTS = %w[
      GPTBot OAI-SearchBot ChatGPT-User ClaudeBot Claude-SearchBot Claude-User PerplexityBot Perplexity-User
      Google-Extended Applebot-Extended CCBot Amazonbot Bytespider meta-externalagent
    ].freeze

    module_function

    def collect(crawl)
      start = URI.parse(crawl.crawl_config.start_url)
      host = CrawlHost.find_by(crawl:, host: start.host)
      document = host&.robots_outcome == "parsed" ? SafeHttp::Robots::Parser.parse(host.robots_txt) : nil
      blocked = AI_BOTS.select { |bot| document && !document.policy_for(bot).allowed?("/") }

      { "ai_bots_checked" => AI_BOTS, "ai_bots_blocked" => blocked, "llms_txt" => llms_txt(crawl, start, host) }
    end

    def llms_txt(crawl, start, host)
      url = "#{start.scheme}://#{start.host}#{":#{start.port}" unless start.port == start.default_port}/llms.txt"
      return { "url" => url, "present" => nil, "error" => "robots" } if host && !host.robots_policy.allowed?(url)

      Crawling.rate_limiter.acquire(start.host, rps: crawl.current_rps, max_wait: 60)
      response = Crawling.http_client(crawl, max_bytes: 64.kilobytes).get(url)
      present = response.success? && !response.header("content-type").to_s.include?("html") && response.body.strip.present?
      { "url" => url, "present" => present, "status" => response.status }
    rescue SafeHttp::Errors::Base => e
      { "url" => url, "present" => nil, "error" => e.message.first(200) }
    end
  end
end
