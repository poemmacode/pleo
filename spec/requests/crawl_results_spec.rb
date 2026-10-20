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
    expect(body).to include("Salud del sitio", "Rastreabilidad", "Metadatos", "Páginas con error 4xx", "Título demasiado largo",
                            "Cómo arreglarlo", "frente al crawl del", "(70)")
    expect(body).to include(crawl.health_score > 70 ? "▲ +" : "▼ ")
    expect(body.index("Páginas con error 4xx")).to be < body.index("Título demasiado largo")
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

  it "filters pages by status class" do
    audit_page("/ok")
    audit_page("/rota", status_code: 404)
    audit_page("/caida", status_code: nil, fetch_error: "Timeout: x")

    get crawl_pages_path(crawl, status: "4xx")
    expect(response.body).to include("https://example.com/rota")
    expect(response.body).not_to include("https://example.com/ok")

    get crawl_pages_path(crawl, status: "error")
    expect(response.body).to include("https://example.com/caida", "Timeout: x")
  end

  it "shows a page with its extraction, structured data, issues and links" do
    page = audit_page("/a", title: "Título", headings: [ { "level" => 1, "text" => "Cabecera" } ])
    other = audit_page("/b")
    audit_link(other, "https://example.com/a")
    audit_link(page, "https://ext.com/", internal: false)
    Audit::LinkGraph.build(crawl)
    PageStructuredDatum.create!(page:, syntax: "json-ld", types: [ "Product" ],
                                validation_errors: [ { "code" => "missing_required", "type" => "Product", "property" => "name" } ])
    add_issue("title.too_short", page:)

    get crawl_page_path(crawl, page)

    expect(response.body).to include("Título", "Cabecera", "Product", "missing_required · Product · name",
                                     "Título demasiado corto", "https://ext.com/", "https://example.com/b")
  end

  it "groups duplicate titles" do
    same = Digest::SHA256.digest("x")
    audit_page("/a", title: "Igual", title_hash: same)
    audit_page("/b", title: "Igual", title_hash: same)

    get crawl_duplicates_path(crawl, type: "title")

    expect(response.body).to include("Igual", "2 páginas", "https://example.com/a", "https://example.com/b")
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
