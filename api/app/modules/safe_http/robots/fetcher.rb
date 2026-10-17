module SafeHttp
  module Robots
    # Fetches and interprets /robots.txt for an origin (RFC 9309 §2.3.1):
    # 2xx → parse; 4xx → no restrictions ("unavailable"); 5xx, 429, network or DNS errors → disallow all
    # ("unreachable"). Redirects are followed (the client allows up to 10, the RFC requires at least 5).
    class Fetcher
      Result = Data.define(:outcome, :status, :policy, :sitemaps, :body, :error) do
        def crawl_delay = policy.crawl_delay
      end

      def initialize(client: Client.new(max_bytes: Parser::MAX_BYTES), token: SafeHttp::BOT_TOKEN)
        @client = client
        @token = token
      end

      def fetch(origin)
        url = URI.join(origin.to_s, "/robots.txt").to_s
        response = @client.get(url)

        case response.status
        when 200..299
          document = Parser.parse(response.body)
          Result.new(:parsed, response.status, document.policy_for(@token), document.sitemaps, response.body, nil)
        when 429, 500..599
          Result.new(:unreachable, response.status, Policy.disallow_all, [], nil, nil)
        when 400..499
          Result.new(:unavailable, response.status, Policy.allow_all, [], nil, nil)
        else
          Result.new(:unreachable, response.status, Policy.disallow_all, [], nil, "estado inesperado #{response.status}")
        end
      rescue Errors::UnsafeTarget, Errors::InvalidUrl
        raise
      rescue Errors::Base => e
        Result.new(:unreachable, nil, Policy.disallow_all, [], nil, e.message)
      end
    end
  end
end
