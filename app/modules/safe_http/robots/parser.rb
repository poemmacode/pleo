module SafeHttp
  module Robots
    # robots.txt parser following RFC 9309.
    #
    # - A group starts with one or more consecutive user-agent lines; a user-agent line after
    #   rule lines starts a new group. Rules before the first user-agent line are ignored.
    # - Sitemap lines are global. Crawl-delay (non-standard) is attached to its group.
    # - Unknown keys are ignored without ending the group.
    class Parser
      MAX_BYTES = 500 * 1024 # RFC 9309 §2.5: parse at least 500 KiB

      Rule = Data.define(:allow, :pattern)
      Group = Data.define(:agents, :rules, :crawl_delay)

      def self.parse(text)
        new(text).parse
      end

      def initialize(text)
        @text = text.to_s.byteslice(0, MAX_BYTES).to_s.scrub("").delete_prefix("﻿")
      end

      def parse
        groups = []
        sitemaps = []
        current = nil
        last_was_agent = false

        @text.each_line do |raw_line|
          key, value = split_line(raw_line)
          next unless key

          case key
          when "user-agent"
            if current.nil? || !last_was_agent
              current = { agents: [], rules: [], crawl_delay: nil }
              groups << current
            end
            current[:agents] << value.downcase unless value.empty?
            last_was_agent = true
          when "allow", "disallow"
            last_was_agent = false
            # An empty disallow means "allow everything" and adds no rule.
            current[:rules] << Rule.new(allow: key == "allow", pattern: Matcher.normalize(value)) if current && !value.empty?
          when "crawl-delay"
            last_was_agent = false
            delay = Float(value, exception: false)
            current[:crawl_delay] = delay if current && delay&.positive?
          when "sitemap"
            sitemaps << value unless value.empty?
          else
            # Unknown directives neither end the user-agent run nor start a new group.
            next
          end
        end

        Document.new(groups: groups.map { Group.new(**_1) }, sitemaps: sitemaps.uniq)
      end

      private
        def split_line(line)
          line = line.sub(/#.*/, "").strip
          return if line.empty? || !line.include?(":")

          key, value = line.split(":", 2)
          key = key.strip.downcase
          key = "disallow" if key == "dissallow" || key == "disalow" # common typos accepted by major crawlers
          [ key, value.strip ]
        end
    end
  end
end
