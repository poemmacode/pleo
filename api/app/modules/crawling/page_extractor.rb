module Crawling
  # Extracts the on-page fields used by the audit checks (docs/03 §4) from a fetched HTML page.
  # Returns attributes for the pages row plus the page's structured data items.
  class PageExtractor
    Result = Data.define(:attributes, :structured_data)

    NON_CONTENT = "script, style, noscript, template, svg, nav, header, footer, iframe, object".freeze
    MIXED_CONTENT_SOURCES = {
      "img" => "src", "script" => "src", "iframe" => "src", "video" => "src", "audio" => "src",
      "source" => "src", "embed" => "src", "object" => "data"
    }.freeze
    MAX_HEADINGS = 200
    MAX_TEXT = 300
    ROBOTS_NAMES = [ "robots", SafeHttp::BOT_TOKEN.downcase ].freeze

    def self.extract(html, url:, headers: {}) = new(html, url, headers).extract

    def initialize(html, url, headers)
      @doc = Nokogiri::HTML(html)
      @url = url
      @headers = headers.transform_keys(&:downcase)
    end

    def extract
      title_nodes = @doc.xpath("//title[not(ancestor::svg)]")
      descriptions = meta_named("description")
      title = title_nodes.first&.text&.squish.presence
      description = descriptions.first&.squish.presence
      canonical_hrefs = head_canonicals + header_canonicals
      canonical = resolved_canonical(canonical_hrefs)
      meta_robots = meta_robots_content
      x_robots = x_robots_content
      directives = "#{meta_robots},#{x_robots}"
      noindex = directives.match?(/\b(noindex|none)\b/)
      words = visible_words

      attributes = {
        extracted: true,
        title:, title_count: title_nodes.size,
        meta_description: description, meta_description_count: descriptions.size,
        title_hash: title && Digest::SHA256.digest(title.downcase),
        description_hash: description && Digest::SHA256.digest(description.downcase),
        meta_robots: meta_robots.presence&.first(255), x_robots_tag: x_robots.presence&.first(255),
        noindex:, nofollow: directives.match?(/\b(nofollow|none)\b/),
        canonical_hrefs:, canonical:,
        lang: @doc.at_xpath("/html/@lang")&.value&.strip&.first(35).presence,
        charset: charset, viewport: meta_named("viewport").first&.first(255),
        hreflang: hreflang_links,
        h1: @doc.css("h1").map { _1.text.squish.first(MAX_TEXT) },
        headings: @doc.css("h1, h2, h3, h4, h5, h6").first(MAX_HEADINGS).map { { level: _1.name[1].to_i, text: _1.text.squish.first(MAX_TEXT) } },
        word_count: words.size, text_simhash: Simhash.compute(words),
        images_count: @doc.css("img").size, images_missing_alt: @doc.css("img:not([alt])").size,
        links_count: @doc.css("a[href]").size, open_graph: open_graph
      }.merge(mixed_content).merge(indexability(noindex, canonical, canonical_hrefs))

      Result.new(attributes:, structured_data: StructuredDataExtractor.extract(@doc, @url))
    end

    private
      def meta_named(name)
        @doc.css("meta[name]").select { _1["name"].to_s.strip.casecmp?(name) }.map { _1["content"].to_s }
      end

      def meta_robots_content
        @doc.css("meta[name]").select { ROBOTS_NAMES.include?(_1["name"].to_s.strip.downcase) }
          .map { _1["content"].to_s.downcase.squish }.join(", ")
      end

      # "X-Robots-Tag: googlebot: noindex" only applies to that bot; unprefixed values apply to all.
      def x_robots_content
        Array(@headers["x-robots-tag"]).flat_map { _1.split(/,(?=\s*[a-z-]+\s*:)/i) }.filter_map do |value|
          agent, rules = value.split(":", 2)
          if rules && !agent.match?(/\A\s*(noindex|nofollow|none|all|max-|noarchive|nosnippet|unavailable_after)/i)
            rules.strip.downcase if ROBOTS_NAMES.include?(agent.strip.downcase)
          else
            value.strip.downcase
          end
        end.join(", ")
      end

      def head_canonicals
        @doc.css("head link[rel][href]").select { _1["rel"].downcase.split.include?("canonical") }.map { _1["href"].strip }
      end

      def header_canonicals
        Array(@headers["link"]).flat_map { _1.split(/,(?=\s*<)/) }
          .select { _1.match?(/;\s*rel="?canonical"?/i) }
          .filter_map { _1[/<([^>]*)>/, 1]&.strip }
      end

      # One canonical URL when all declarations agree; nil when missing or conflicting.
      def resolved_canonical(hrefs)
        resolved = hrefs.filter_map { UrlNormalizer.resolve(@url, _1) }.uniq
        resolved.first if resolved.size == 1
      end

      def indexability(noindex, canonical, canonical_hrefs)
        reason = if noindex then "noindex"
        elsif canonical_hrefs.any? && canonical.nil? then "canonical_conflict"
        elsif canonical && canonical != @url then "canonicalized"
        end
        { indexable: reason.nil?, indexability_reason: reason }
      end

      def charset
        @doc.at_css("meta[charset]")&.[]("charset")&.strip&.downcase.presence ||
          @doc.css("meta[http-equiv]").find { _1["http-equiv"].casecmp?("content-type") }&.[]("content").to_s[/charset=([\w-]+)/i, 1]&.downcase ||
          Array(@headers["content-type"]).first.to_s[/charset=([\w-]+)/i, 1]&.downcase
      end

      def hreflang_links
        @doc.css("head link[rel][hreflang][href]").select { _1["rel"].downcase.split.include?("alternate") }.first(300).map do |node|
          { lang: node["hreflang"].strip.first(35), href: UrlNormalizer.resolve(@url, node["href"]) || node["href"].strip.first(2000) }
        end
      end

      def visible_words
        body = @doc.at_css("body")
        return [] unless body

        body = body.dup
        body.css(NON_CONTENT).each(&:remove)
        # Join text nodes with spaces: adjacent blocks (</h1><p>) have no whitespace between them.
        body.xpath(".//text()").map(&:text).join(" ").scan(/[\p{L}\p{N}]+(?:['’]\p{L}+)?/).map(&:downcase)
      end

      def mixed_content
        return { mixed_content_count: 0, mixed_content_samples: [] } unless @url.start_with?("https://")

        insecure = MIXED_CONTENT_SOURCES.flat_map { |tag, attr| @doc.css("#{tag}[#{attr}]").map { _1[attr].strip } }
        insecure += @doc.css("link[rel][href]").select { _1["rel"].downcase.split.include?("stylesheet") }.map { _1["href"].strip }
        insecure = insecure.select { _1.match?(%r{\Ahttp://}i) }.uniq
        { mixed_content_count: insecure.size, mixed_content_samples: insecure.first(10) }
      end

      def open_graph
        @doc.css("meta[property^='og:']").each_with_object({}) do |node, og|
          key = node["property"].delete_prefix("og:")
          og[key] ||= node["content"].to_s.first(500) if %w[title description image type url].include?(key)
        end
      end
  end
end
