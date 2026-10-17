require "ipaddr"

# Every outbound request to a user-supplied URL goes through SafeHttp (docs/03-mvp-crawler.md §3).
module SafeHttp
  BOT_TOKEN = "SEOPlatformBot".freeze

  class Config
    attr_accessor :allowed_ports, :user_agent
    attr_writer :resolver
    attr_reader :test_allowed_ips

    def initialize
      @allowed_ports = ENV.fetch("SAFE_HTTP_ALLOWED_PORTS", "80,443").split(",").map { Integer(_1.strip) }
      @user_agent = "#{BOT_TOKEN}/0.1 (+#{ENV.fetch("BOT_INFO_URL", "https://github.com/seo-platform/bot")}; uso personal)"
      @test_allowed_ips = []
    end

    def resolver
      @resolver ||= Resolver.new
    end

    # Lets specs reach the local test server. Refuses to work anywhere but the test environment.
    def allow_ips_for_tests!(ips)
      raise SecurityError, "test-only IP allowlist used outside the test environment" unless Rails.env.test?

      @test_allowed_ips = ips.map { IPAddr.new(_1) }
    end
  end

  def self.config
    @config ||= Config.new
  end

  def self.reset_config!
    @config = Config.new
  end

  # Redis for cross-process coordination (per-host rate limits). Separate from Sidekiq's pool.
  def self.redis
    @redis ||= RedisClient.config(url: ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/1"))
      .new_pool(size: Integer(ENV.fetch("RAILS_MAX_THREADS", 5)) + 5, timeout: 5)
  end

  class << self
    attr_writer :redis
  end
end
