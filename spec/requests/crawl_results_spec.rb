require "rails_helper"

RSpec.describe "Crawl results (pages, issues, duplicates)" do
  let(:crawl) { audit_crawl }

  before do
    sign_in(crawl.project.user)
    Audit::Catalog.sync_definitions!
  end

  def add_issue(key, page: nil, url: page&.url, details: {})
    Issue.create!(crawl:, check_key: key, page:, url:, details:)
  end

  it "shows the health score, categories, comparison and issues by priority with Spanish guidance" do
    previous = Crawl.create!(project: crawl.project, domain: crawl.domain, status: "completed", current_rps: 1, health_score: 70.0,
                             config: crawl.config, created_at: 1.week.ago)
    a = audit_page("/a")
    add_issue("title.too_long", page: a)
    add_issue("http.4xx", page: a)
    Audit::Scoring.call(crawl)
    crawl.update!(audit_status: "done")

    get crawl_path(crawl)

    body = response.body
    expect(body).to include("Site health", "Crawlability", "Metadata", "Pages returning 4xx errors", "Title too long",
                            "How to fix it", "compared with the crawl of", "(70)")
    expect(body).to include(crawl.health_score > 70 ? "▲ +" : "▼ −")
    expect(body).not_to include("−-")
    expect(body.index("Pages returning 4xx errors")).to be < body.index("Title too long")
    expect(previous.reload.health_score).to eq(70)
    expect(body).to include(%(src="#{crawl_issue_path(crawl, "http.4xx")}"))
  end

  it "lists the findings of one check, most important first, and appends more with Turbo Streams" do
    stub_const("CrawlScoped::PAGE_SIZE", 2)
    3.times { add_issue("http.4xx", page: audit_page("/p#{_1}"), details: { "status" => 404 }) }

    get crawl_issue_path(crawl, "http.4xx")
    expect(response.body).to include('<turbo-frame id="issue_http-4xx"', "https://example.com/p0", "status: 404")
    expect(response.body).not_to include("https://example.com/p2")
    expect(response.body).to include("page=2")

    get crawl_issue_path(crawl, "http.4xx", page: 2), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include('action="append" target="findings_http-4xx"', "https://example.com/p2")

    get crawl_issue_path(crawl, "no.such_check")
    expect(response).to have_http_status(:not_found)
  end

  it "shows PageSpeed results on the crawl and on the page detail" do
    page = audit_page("/slow")
    PerformanceResult.create!(crawl:, page:, fetched_at: Time.current, performance_score: 38, lcp_ms: 5200, cls: 0.31, tbt_ms: 640,
                              field_scope: "url", field_category: "SLOW", field_lcp_ms: 4600, field_inp_ms: 620, field_cls: 0.12,
                              opportunities: [ { "id" => "x", "title" => "Improve image delivery", "savings_ms" => 1500 } ])
    crawl.update!(audit_status: "done", performance_status: "done")

    get crawl_path(crawl)
    expect(response.body).to include("Mobile performance", "https://example.com/slow", "5.2 s", "0.31",
                                     "slow (this page): LCP 4.6 s, INP 620 ms, CLS 0.12", "Top improvement: Improve image delivery")

    get crawl_page_path(crawl, page)
    expect(response.body).to include("Speed Index", "estimated saving 1.5 s")
  end

  it "explains when PageSpeed was skipped for lack of an API key" do
    crawl.update!(audit_status: "done", performance_status: "skipped_no_key")

    get crawl_path(crawl)
    expect(response.body).to include("the PageSpeed Insights API key is missing")
  end

  it "filters pages by status class" do
    audit_page("/ok")
    audit_page("/broken", status_code: 404)
    audit_page("/down", status_code: nil, fetch_error: "Timeout: x")

    get crawl_pages_path(crawl, status: "4xx")
    expect(response.body).to include("https://example.com/broken")
    expect(response.body).not_to include("https://example.com/ok")

    get crawl_pages_path(crawl, status: "error")
    expect(response.body).to include("https://example.com/down", "Timeout: x")
  end

  it "shows a page with its extraction, structured data, issues and links" do
    page = audit_page("/a", title: "Page title", headings: [ { "level" => 1, "text" => "Main heading" } ])
    other = audit_page("/b")
    audit_link(other, "https://example.com/a")
    audit_link(page, "https://ext.com/", internal: false)
    Audit::LinkGraph.build(crawl)
    PageStructuredDatum.create!(page:, syntax: "json-ld", types: [ "Product" ],
                                validation_errors: [ { "code" => "missing_required", "type" => "Product", "property" => "name" } ])
    add_issue("title.too_short", page:)

    get crawl_page_path(crawl, page)

    expect(response.body).to include("Page title", "Main heading", "Product", "missing_required · Product · name",
                                     "Title too short", "https://ext.com/", "https://example.com/b")
  end

  it "groups duplicate titles" do
    same = Digest::SHA256.digest("x")
    audit_page("/a", title: "Same title", title_hash: same)
    audit_page("/b", title: "Same title", title_hash: same)

    get crawl_duplicates_path(crawl, type: "title")

    expect(response.body).to include("Same title", "2 pages", "https://example.com/a", "https://example.com/b")
  end

  it "does not expose other users' results" do
    delete session_path
    sign_in(create(:user))

    get crawl_issue_path(crawl, "http.4xx")
    expect(response).to have_http_status(:not_found)
    get crawl_duplicates_path(crawl)
    expect(response).to have_http_status(:not_found)
  end
end
