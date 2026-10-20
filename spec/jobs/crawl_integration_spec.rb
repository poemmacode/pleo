require "rails_helper"

RSpec.describe "Crawling a site end to end", type: :job do
  include ActiveJob::TestHelper

  let(:server) { TestHttpServer.new }
  let!(:origin) { FixtureSite.build(server) }
  let(:domain) { create(:domain, host_input: FixtureSite::HOST, verified_at: Time.current) }

  before do
    SafeHttp.config.allow_ips_for_tests!([ "127.0.0.1" ])
    SafeHttp.config.allowed_ports = [ server.port ]
    SafeHttp.config.resolver = StubResolver.new(FixtureSite::HOST => [ "127.0.0.1" ])
    Crawling.rate_limiter = NullRateLimiter.new
  end

  after do
    server.stop
    Crawling.rate_limiter = nil
  end

  def run_crawl(**config)
    stored = Crawling::CrawlConfig.build({ start_url: "#{origin}/", max_depth: 3 }.merge(config), domain:).to_stored
    crawl = create_crawl(stored)
    perform_enqueued_jobs { Crawling::StartCrawlJob.perform_later(crawl.id) }
    crawl.reload
  end

  def create_crawl(config)
    Crawl.create!(project: domain.project, domain:, config:, current_rps: config["requests_per_second"])
  end

  def paths(scope) = scope.map { URI.parse(_1.url).request_uri }.sort

  it "discovers from sitemaps and links, respects robots.txt and depth, and stores every page once" do
    crawl = run_crawl

    expect(crawl).to have_attributes(status: "completed", status_reason: nil, sitemap_status: "done")
    expect(paths(crawl.pages)).to eq(%w[/ /about /blog/ /blog/page /blog/post-1 /deep/1 /deep/2 /deep/3 /missing /old /orphan])
    expect(crawl.crawl_urls.where(state: "skipped").pluck(:url, :skip_reason)).to eq([ [ "#{origin}/private/secret", "robots" ] ])
    expect(crawl).to have_attributes(pages_discovered: 12, pages_crawled: 11, pages_failed: 0, pages_skipped: 1,
                                     sitemap_urls_out_of_scope: 1)
    expect(server.received.map { _1[:path] }).not_to include("/private/secret", "/deep/4")
  end

  it "records statuses, redirects, depth and sitemap membership" do
    crawl = run_crawl
    page = ->(path) { crawl.pages.find_by!(url: "#{origin}#{path}") }

    expect(page.call("/old")).to have_attributes(status_code: 301, redirect_url: "#{origin}/about")
    expect(page.call("/missing").status_code).to eq(404)
    expect(crawl.pages.where.not(status_code: 301).where.not(redirect_url: nil)).to be_empty
    expect(page.call("/")).to have_attributes(depth: 0, in_sitemap: true)
    expect(page.call("/about")).to have_attributes(depth: 1, in_sitemap: true)
    expect(page.call("/orphan")).to have_attributes(depth: nil, in_sitemap: true)
    expect(page.call("/deep/3").depth).to eq(3)
    expect(page.call("/").body).to include("Sobre nosotros")
  end

  it "extracts on-page fields while crawling and marks non-HTML or failed pages as not indexable" do
    crawl = run_crawl(use_sitemaps: false)
    page = ->(path) { crawl.pages.find_by!(url: "#{origin}#{path}") }

    expect(page.call("/")).to have_attributes(extracted: true, title: "t", indexable: true, links_count: 9)
    expect(page.call("/old")).to have_attributes(extracted: false, indexable: false, indexability_reason: "status_301")
    expect(page.call("/missing").indexability_reason).to eq("status_404")
  end

  it "audits the finished crawl and produces exactly the expected issues (golden)" do
    crawl = run_crawl
    html_pages = %w[/ /about /blog/ /blog/page /blog/post-1 /deep/1 /deep/2 /deep/3 /orphan]
    on_every_html_page = %w[canonical.missing content.thin h1.missing https.not_used meta_description.missing
                            mobile.viewport_missing schema.none title.duplicate title.too_short]
    expected = on_every_html_page.index_with { html_pages }.merge(
      "ai.llms_txt_missing" => %w[/llms.txt],
      "http.4xx" => %w[/missing],
      "links.internal_broken" => %w[/],
      "links.internal_nofollow" => %w[/blog/],
      "links.to_redirect" => %w[/],
      "page.orphan" => %w[/orphan],
      "robots.blocked_internal_linked" => %w[/private/secret]
    )

    actual = crawl.issues.group_by(&:check_key).transform_values { |issues| issues.map { _1.url.delete_prefix(origin) }.sort }
    expect(crawl.audit_status).to eq("done")
    expect(crawl.health_score).to be_between(0, 100)
    expect(crawl.category_scores.keys).to match_array(Audit::Scoring::CATEGORY_WEIGHTS.keys)
    expect(crawl.issues.where(priority_score: nil)).not_to exist
    expect(actual).to eq(expected.transform_values(&:sort))
    expect(crawl.pages.find_by!(url: "#{origin}/about")).to have_attributes(inlinks_count: 1, internal_pagerank: a_value > 0)
  end

  it "stores links with anchors, rel and internal flag, normalizing URLs" do
    crawl = run_crawl
    home = crawl.pages.find_by!(url: "#{origin}/")
    links = home.links.pluck(:to_url, :internal, :anchor)

    expect(links).to include([ "#{origin}/about", true, "Sobre nosotros" ], [ "https://external.example.net/", false, "Externo" ])
    expect(links.map(&:first)).not_to include(a_string_starting_with("mailto"))
    expect(crawl.pages.find_by!(url: "#{origin}/blog/").links.pluck(:to_url, :rel))
      .to contain_exactly([ "#{origin}/blog/post-1", [ "nofollow" ] ], [ "#{origin}/blog/page", [] ])
  end

  it "does not follow nofollow links when asked to" do
    crawl = run_crawl(respect_nofollow: true, use_sitemaps: false)

    expect(paths(crawl.pages)).not_to include("/blog/post-1")
    expect(crawl.sitemap_status).to eq("skipped")
  end

  it "never fetches more than max_pages and marks the rest as skipped" do
    crawl = run_crawl(max_pages: 3, use_sitemaps: false)

    expect(crawl.pages.count).to eq(3)
    expect(crawl).to have_attributes(status: "completed", status_reason: "max_pages_reached")
    expect(crawl.crawl_urls.where(skip_reason: "limit")).to exist
    expect(crawl.crawl_urls.where(state: "pending")).not_to exist
  end

  it "applies include and exclude patterns" do
    crawl = run_crawl(exclude_patterns: [ "^/deep" ], use_sitemaps: false)

    expect(paths(crawl.pages).grep(%r{/deep})).to be_empty
  end

  it "skips URLs whose host resolves to a private address" do
    SafeHttp.config.resolver = StubResolver.new(FixtureSite::HOST => [ "127.0.0.1" ], "evil.#{FixtureSite::HOST}" => [ "10.0.0.7" ])
    server.route("/", [ 200, { "Content-Type" => "text/html" }, %(<a href="http://evil.#{FixtureSite::HOST}:#{server.port}/">x</a>) ])

    crawl = run_crawl(use_sitemaps: false)

    expect(crawl.crawl_urls.find_by(url: "http://evil.#{FixtureSite::HOST}:#{server.port}/"))
      .to have_attributes(state: "skipped", skip_reason: "unsafe_host")
  end

  it "ends without fetching pages when robots.txt is unreachable" do
    server.route("/robots.txt", [ 503, {}, "" ])

    crawl = run_crawl(use_sitemaps: false)

    expect(crawl).to have_attributes(status: "completed", status_reason: "robots_unreachable", pages_crawled: 0)
    expect(server.received.map { _1[:path] }).to eq([ "/robots.txt" ])
  end

  it "retries 503 responses and records the page after the last attempt" do
    server.route("/about", [ 503, { "Retry-After" => "0" }, "" ])

    crawl = run_crawl(use_sitemaps: false)

    expect(server.received.count { _1[:path] == "/about" }).to eq(3)
    expect(crawl.pages.find_by!(url: "#{origin}/about").status_code).to eq(503)
  end

  it "does nothing while paused and finishes after resuming" do
    stored = Crawling::CrawlConfig.build({ start_url: "#{origin}/", use_sitemaps: false }, domain:).to_stored
    crawl = create_crawl(stored)
    crawl.update!(status: "running", started_at: Time.current, sitemap_status: "skipped")
    Crawling::Frontier.new(crawl).add([ "#{origin}/" ], source: "seed", depth: 0)
    Crawling::Lifecycle.pause(crawl)

    perform_enqueued_jobs { Crawling::FetchLaneJob.perform_later(crawl.id) }
    expect(server.received).to be_empty

    perform_enqueued_jobs { Crawling::Lifecycle.resume(crawl) }
    expect(crawl.reload.status).to eq("completed")
    expect(crawl.pages.count).to be > 1
  end
end
