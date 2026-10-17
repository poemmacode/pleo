module Crawling
  # Streams <loc> entries out of a sitemap or sitemap index (plain or gzip-compressed file),
  # without building a DOM. External entities and network access are disabled.
  module SitemapReader
    Entry = Data.define(:kind, :loc) # kind: :sitemap (from an index) or :url
    GZIP_MAGIC = "\x1F\x8B".b

    module_function

    def entries(body, max_bytes: Crawling::SITEMAP_MAX_BYTES)
      xml = decompress(body, max_bytes)
      reader = Nokogiri::XML::Reader(xml, nil, nil, Nokogiri::XML::ParseOptions::NONET | Nokogiri::XML::ParseOptions::RECOVER)
      kind = nil
      entries = []
      reader.each do |node|
        next unless node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT

        case node.local_name
        when "sitemapindex" then kind = :sitemap
        when "urlset" then kind = :url
        when "loc"
          loc = node.inner_xml.to_s.strip.delete_prefix("<![CDATA[").delete_suffix("]]>").strip
          entries << Entry.new(kind: kind || :url, loc: CGI.unescapeHTML(loc)) unless loc.empty?
        end
      end
      entries
    rescue Nokogiri::XML::SyntaxError, RuntimeError # the pull reader raises RuntimeError on truncated input
      entries || []
    end

    # A .xml.gz file is served as gzip bytes (not Content-Encoding), so it is inflated here, capped.
    def decompress(body, max_bytes)
      return body unless body.b.start_with?(GZIP_MAGIC)

      reader = SafeHttp::BodyReader.new("gzip", max_bytes)
      begin
        reader << body
        reader.finish
      rescue SafeHttp::BodyReader::LimitReached
        nil
      end
      reader.body
    end
  end
end
