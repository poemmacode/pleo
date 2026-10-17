module AuditHelpers
  GOOD_PAGE = {
    status_code: 200, content_type: "text/html", extracted: true, indexable: true, depth: 1, in_sitemap: false,
    title: "Guía completa de SEO técnico", title_count: 1, meta_description: "D" * 120, meta_description_count: 1,
    h1: [ "SEO técnico paso a paso" ], headings: [ { "level" => 1, "text" => "SEO" }, { "level" => 2, "text" => "A" } ],
    word_count: 800, viewport: "width=device-width", images_count: 2, images_missing_alt: 0, mixed_content_count: 0,
    links_count: 40, response_ms: 200, content_length: 30_000, inlinks_count: 3, hreflang: []
  }.freeze

  def audit_crawl
    @audit_crawl ||= begin
      domain = create(:domain, host_input: "example.com", verified_at: Time.current)
      Crawl.create!(project: domain.project, domain:, status: "completed", current_rps: 1, sitemap_status: "done",
                    config: { "start_url" => "https://example.com/" })
    end
  end

  # Creates a page (and its frontier row) that passes every check unless overridden.
  def audit_page(path, **attrs)
    url = path.start_with?("http") ? path : "https://example.com#{path}"
    crawl_url = CrawlUrl.create!(crawl: audit_crawl, url:, url_hash: CrawlUrl.hash_url(url), source: "link", state: "done")
    defaults = GOOD_PAGE.merge(canonical: url, canonical_hrefs: [ url ])
    Page.create!(defaults.merge(attrs).merge(crawl: audit_crawl, crawl_url:, url:, fetched_at: Time.current))
  end

  def audit_link(from, to_url, internal: true, rel: [])
    Link.create!(crawl_id: audit_crawl.id, from_page: from, to_url:, to_url_hash: CrawlUrl.hash_url(to_url), internal:, rel:)
  end

  def findings_for(check_class)
    Audit::LinkGraph.build(audit_crawl) if Link.where(crawl_id: audit_crawl.id).exists?
    check_class.new(Audit::Context.new(audit_crawl.reload)).findings
  end

  def flagged_urls(check_class) = findings_for(check_class).map(&:url)
end

RSpec.configure { |config| config.include AuditHelpers }
