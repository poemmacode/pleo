# PageSpeed Insights (Lighthouse lab data + CrUX field data) for a sample of crawled pages (Épica E).
module Performance
  ENDPOINT = "https://www.googleapis.com/pagespeedonline/v5/runPagespeed".freeze

  def self.api_key = ENV["PAGESPEED_API_KEY"].presence

  # Requests per crawl day across all crawls; PSI's default quota is far higher, this is a safety cap.
  def self.daily_limit = Integer(ENV.fetch("PAGESPEED_DAILY_LIMIT", 500))

  class << self
    attr_writer :client

    # Swappable in tests; defaults to a real PSI client when a key is configured.
    def client
      @client || (api_key && Client.new(api_key:))
    end
  end
end
