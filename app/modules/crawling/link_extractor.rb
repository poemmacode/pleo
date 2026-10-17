module Crawling
  # Pulls crawlable links out of an HTML page, honouring <base href>.
  module LinkExtractor
    Link = Data.define(:url, :anchor, :rel)
    Result = Data.define(:links, :meta_nofollow)

    MAX_LINKS = 5_000
    MAX_ANCHOR = 500
    ROBOTS_META_NAMES = [ "robots", SafeHttp::BOT_TOKEN.downcase ].freeze

    module_function

    def extract(html, page_url)
      doc = Nokogiri::HTML(html)
      base = base_url(doc, page_url)
      robots_meta = doc.css("meta[name]").select { ROBOTS_META_NAMES.include?(_1["name"].to_s.downcase) }
        .map { _1["content"].to_s.downcase }.join(",")

      links = doc.css("a[href], area[href]").first(MAX_LINKS).filter_map do |node|
        url = UrlNormalizer.resolve(base, node["href"])
        next unless url

        anchor = (node.name == "area" ? node["alt"] : node.text).to_s.squish.first(MAX_ANCHOR)
        anchor = node.at_css("img[alt]")&.[]("alt").to_s.squish.first(MAX_ANCHOR) if anchor.empty?
        Link.new(url:, anchor:, rel: node["rel"].to_s.downcase.split)
      end

      Result.new(links:, meta_nofollow: robots_meta.match?(/\b(nofollow|none)\b/))
    end

    def base_url(doc, page_url)
      href = doc.at_css("base[href]")&.[]("href")
      (href && UrlNormalizer.resolve(page_url, href)) || page_url
    end
  end
end
