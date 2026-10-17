module SafeHttp
  module Robots
    class Document
      attr_reader :groups, :sitemaps

      def initialize(groups:, sitemaps:)
        @groups = groups
        @sitemaps = sitemaps
      end

      # Merges every group naming the product token (case-insensitive); falls back to "*" groups.
      def policy_for(token = SafeHttp::BOT_TOKEN)
        token = token.downcase
        matching = groups.select { |group| group.agents.any? { agent_token(_1) == token } }
        matching = groups.select { |group| group.agents.include?("*") } if matching.empty?

        Policy.new(rules: matching.flat_map(&:rules), crawl_delay: matching.filter_map(&:crawl_delay).max)
      end

      private
        # "SEOPlatformBot/1.0 (+info)" in a user-agent line still names the SEOPlatformBot token.
        def agent_token(agent)
          agent[/\A[a-z0-9_-]+/i].to_s.downcase.presence || agent
        end
    end
  end
end
