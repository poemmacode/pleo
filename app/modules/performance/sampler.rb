module Performance
  # Picks which pages to measure: the start page, then one page per URL template (most linked first),
  # then the highest internal PageRank pages, up to `size`. Only indexable 200 HTML pages.
  module Sampler
    module_function

    def pick(crawl, size:)
      candidates = crawl.pages.where(status_code: 200, indexable: true, extracted: true)
        .order(Arel.sql("internal_pagerank DESC NULLS LAST, id")).to_a
      start = Crawling::UrlNormalizer.normalize(crawl.crawl_config.start_url)
      chosen = candidates.select { _1.url == start }
      candidates.group_by { template(_1.url) }.each_value { |pages| chosen << pages.first }
      chosen.concat(candidates)
      chosen.uniq.first(size)
    end

    # "/blog/2024/mi-post-42" → "/blog/:n/*": numbers and the last slug collapse so similar pages share a template.
    def template(url)
      segments = URI.parse(url).path.split("/").reject(&:empty?)
      return "/" if segments.empty?

      segments = segments.map { _1.match?(/\d/) ? ":n" : _1 }
      (segments[0...-1] + [ segments.size > 1 ? "*" : segments.last ]).join("/").prepend("/")
    rescue URI::Error
      "/"
    end
  end
end
