require "rails_helper"

RSpec.describe "Crawl issues and page detail API" do
  include ActiveJob::TestHelper

  let(:crawl) { audit_crawl }

  before do
    sign_in(crawl.project.user)
    Audit::Catalog.sync_definitions!
  end

  def add_issue(key, page: nil, url: page&.url, details: {})
    Issue.create!(crawl:, check_key: key, page:, url:, details:)
  end

  it "summarises issues by check, most severe first, with Spanish guidance" do
    a = audit_page("/a")
    b = audit_page("/b")
    add_issue("title.too_long", page: a)
    add_issue("http.4xx", page: a)
    add_issue("http.4xx", page: b)
    add_issue("h1.missing", page: b)

    get "/api/v1/crawls/#{crawl.id}/issues"

    expect(json["data"].map { [ _1["check_key"], _1["severity"], _1["count"] ] })
      .to eq([ [ "http.4xx", "error", 2 ], [ "h1.missing", "warning", 1 ], [ "title.too_long", "warning", 1 ] ])
    expect(json["data"].first).to include("title" => "Páginas con error 4xx", "how_to_fix" => a_string_including("301"))
    expect(json.dig("meta", "by_severity")).to eq("error" => 2, "warning" => 2, "notice" => 0)
  end

  it "lists the findings of one check with pagination" do
    3.times { add_issue("http.4xx", page: audit_page("/p#{_1}"), details: { "status" => 404 }) }

    get "/api/v1/crawls/#{crawl.id}/issues/http.4xx", params: { limit: 2 }
    expect(json["data"].size).to eq(2)
    expect(json["data"].first).to include("url" => "https://example.com/p0", "details" => { "status" => 404 })

    get "/api/v1/crawls/#{crawl.id}/issues/http.4xx", params: { after: json.dig("meta", "next_cursor") }
    expect(json["data"].map { _1["url"] }).to eq([ "https://example.com/p2" ])

    get "/api/v1/crawls/#{crawl.id}/issues/no.such_check"
    expect(response).to have_http_status(:not_found)
  end

  it "returns a page with its extraction, structured data, issues and links" do
    page = audit_page("/a", title: "Título", hreflang: [ { "lang" => "en", "href" => "https://example.com/en" } ])
    other = audit_page("/b")
    audit_link(other, "https://example.com/a")
    audit_link(page, "https://ext.com/", internal: false)
    Audit::LinkGraph.build(crawl)
    PageStructuredDatum.create!(page:, syntax: "json-ld", types: [ "Product" ], data: { "@type" => "Product" },
                                validation_errors: [ { "code" => "missing_required", "property" => "name" } ])
    add_issue("title.too_short", page:)

    get "/api/v1/crawls/#{crawl.id}/pages/#{page.id}"

    data = json["data"]
    expect(data).to include("title" => "Título", "hreflang" => [ { "lang" => "en", "href" => "https://example.com/en" } ], "inlinks_count" => 1)
    expect(data["structured_data"].first).to include("types" => [ "Product" ], "validation_errors" => [ { "code" => "missing_required", "property" => "name" } ])
    expect(data["issues"]).to eq([ { "check_key" => "title.too_short", "severity" => "notice", "title" => "Título demasiado corto", "details" => {} } ])
    expect(data["inlinks"]).to eq([ { "url" => "https://example.com/b", "anchor" => nil } ])
    expect(data["outlinks"]).to eq([ { "url" => "https://ext.com/", "anchor" => nil, "internal" => false, "rel" => [] } ])
  end

  it "groups duplicate titles and validates the type" do
    same = Digest::SHA256.digest("x")
    audit_page("/a", title: "Igual", title_hash: same)
    audit_page("/b", title: "Igual", title_hash: same)
    audit_page("/c", title: "Distinto", title_hash: Digest::SHA256.digest("y"))

    get "/api/v1/crawls/#{crawl.id}/duplicates", params: { type: "title" }
    expect(json["data"]).to match([ a_hash_including("size" => 2, "value" => "Igual") ])

    get "/api/v1/crawls/#{crawl.id}/duplicates", params: { type: "nope" }
    expect(response).to have_http_status(:bad_request)
  end

  it "re-runs the audit for completed crawls only" do
    expect { post "/api/v1/crawls/#{crawl.id}/audit" }.to have_enqueued_job(Audit::RunAuditJob).with(crawl.id)
    expect(response).to have_http_status(:accepted)

    crawl.update!(status: "running")
    post "/api/v1/crawls/#{crawl.id}/audit"
    expect(response).to have_http_status(:conflict)
  end

  it "does not expose other users' issues" do
    other = create(:user)
    delete "/api/v1/session"
    sign_in(other)

    get "/api/v1/crawls/#{crawl.id}/issues"
    expect(response).to have_http_status(:not_found)
  end
end
