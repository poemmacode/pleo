# Seeds the frontier from the sitemaps declared in robots.txt plus /sitemap.xml (docs/03 §2).
# Follows sitemap indexes up to MAX_DEPTH levels; only fetches sitemaps on hosts covered by the
# verified domain, and only adds URLs inside the crawl scope.
class Crawling::SitemapDiscoveryJob < ApplicationJob
  queue_as :crawl_control

  MAX_DEPTH = 3
  MAX_FILES = 200

  def perform(crawl_id)
    crawl = Crawl.find_by(id: crawl_id)
    return unless crawl && %w[running paused].include?(crawl.status)

    report = discover(crawl)
    crawl.update!(sitemaps: report, sitemap_status: "done")
    Crawling::Lifecycle.dispatch(crawl) if crawl.reload.running?
  rescue StandardError
    crawl&.update!(sitemap_status: "done")
    Crawling::Lifecycle.dispatch(crawl) if crawl&.reload&.running?
    raise
  end

  private
    def discover(crawl)
      frontier = Crawling::Frontier.new(crawl)
      start = URI.parse(crawl.crawl_config.start_url)
      start_host = Crawling::HostRegistry.fetch(crawl, crawl.crawl_config.start_url)
      queue = (start_host.sitemaps + [ "#{start.scheme}://#{start.host}#{":#{start.port}" unless start.port == start.default_port}/sitemap.xml" ])
        .filter_map { Crawling::UrlNormalizer.normalize(_1) }.uniq.map { [ _1, 0 ] }
      seen = Set.new
      report = []
      client = Crawling.http_client(crawl, max_bytes: Crawling::SITEMAP_MAX_BYTES)

      while (url, level = queue.shift) && seen.size < MAX_FILES
        next if seen.include?(url)

        seen << url
        entry = { url:, status: nil, urls: 0, added: 0, out_of_scope: 0, error: nil }
        report << entry
        host = URI.parse(url).host
        unless Crawling::Scope.host_within?(host, crawl.domain.host)
          entry[:error] = "host fuera del dominio verificado"
          next
        end
        unless Crawling::HostRegistry.fetch(crawl, url).robots_policy.allowed?(url)
          entry[:error] = "bloqueado por robots.txt"
          next
        end

        begin
          Crawling.rate_limiter.acquire(host, rps: crawl.current_rps, max_wait: 60)
          response = client.get(url)
        rescue SafeHttp::Errors::Base => e
          entry[:error] = e.message.first(200)
          next
        end
        entry[:status] = response.status
        next unless response.success?

        entries = Crawling::SitemapReader.entries(response.body)
        child_sitemaps, page_urls = entries.partition { _1.kind == :sitemap }
        child_sitemaps.each do |child|
          normalized = Crawling::UrlNormalizer.normalize(child.loc)
          queue << [ normalized, level + 1 ] if normalized && level < MAX_DEPTH
        end

        normalized = page_urls.filter_map { Crawling::UrlNormalizer.normalize(_1.loc) }
        in_scope, outside = normalized.partition { crawl.crawl_scope.include?(_1) }
        entry[:urls] = page_urls.size
        entry[:out_of_scope] = outside.size
        entry[:added] = frontier.add(in_scope, source: "sitemap", depth: nil, in_sitemap: true)
        crawl.increment!(sitemap_urls_out_of_scope: outside.size) if outside.any?
      end
      report
    end
end
