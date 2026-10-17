module SafeHttp
  module Robots
    class Policy
      ALWAYS_ALLOWED = "/robots.txt".freeze

      attr_reader :rules, :crawl_delay

      def self.allow_all = new(rules: [], crawl_delay: nil)

      def self.disallow_all = new(rules: [ Parser::Rule.new(allow: false, pattern: "/") ], crawl_delay: nil)

      def initialize(rules:, crawl_delay:)
        @rules = rules
        @crawl_delay = crawl_delay
      end

      # The longest matching pattern wins; on a tie between allow and disallow, allow wins (RFC 9309 §2.2.2).
      def allowed?(url_or_path)
        path = url_or_path.to_s.start_with?("/") ? Matcher.normalize(url_or_path.to_s) : Matcher.path_for(url_or_path)
        return true if path == ALWAYS_ALLOWED

        best = nil
        rules.each do |rule|
          next unless Matcher.matches?(rule.pattern, path)

          length = rule.pattern.length
          if best.nil? || length > best.pattern.length || (length == best.pattern.length && rule.allow)
            best = rule
          end
        end
        best.nil? || best.allow
      end
    end
  end
end
