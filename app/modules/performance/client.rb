module Performance
  # Calls the PSI v5 API through SafeHttp (fixed Google host). Lighthouse runs on Google's servers
  # against the public URL, so a run takes 10–60 s.
  class Client
    MAX_BYTES = 20 * 1024 * 1024

    Error = Class.new(StandardError)

    def initialize(api_key:, http: SafeHttp::Client.new(max_bytes: MAX_BYTES, read_timeout: 90, total_timeout: 120))
      @api_key = api_key
      @http = http
    end

    # Returns the parsed JSON body; raises Error with PSI's message on failure (never the URL: it holds the key).
    def run(url, strategy: "mobile")
      query = URI.encode_www_form(url:, strategy:, category: "performance", locale: "es", key: @api_key)
      response = @http.get("#{ENDPOINT}?#{query}")
      body = JSON.parse(response.body) rescue {}
      return body if response.success?

      raise Error, (body.dig("error", "message") || "HTTP #{response.status}").to_s.first(300)
    rescue SafeHttp::Errors::Base => e
      raise Error, e.class.name.demodulize
    end
  end
end
