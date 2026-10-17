require "rails_helper"

RSpec.describe "Crawls API" do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:project) { create(:project, user:) }
  let(:domain) { create(:domain, project:, host_input: "example.com", verified_at: Time.current) }

  before do
    sign_in(user)
    SafeHttp.config.resolver = StubResolver.new("example.com" => [ "93.184.215.14" ], "rival.com" => [ "93.184.215.15" ])
  end

  def create_crawl(attrs = {})
    post "/api/v1/projects/#{project.id}/crawls", params: { crawl: { domain_id: domain.id }.merge(attrs) }, as: :json
  end

  it "queues a crawl with validated settings and returns 202" do
    expect { create_crawl(max_pages: 100, requests_per_second: 1, exclude_patterns: [ "^/tag/" ]) }
      .to have_enqueued_job(Crawling::StartCrawlJob)

    expect(response).to have_http_status(:accepted)
    data = json["data"]
    expect(data).to include("status" => "queued", "current_rps" => 1.0)
    expect(data["config"]).to include("start_url" => "https://example.com/", "max_pages" => 100, "exclude_patterns" => [ "^/tag/" ])
    expect(data["progress"]).to include("crawled" => 0, "max_pages" => 100)
  end

  it "returns field errors for out-of-range settings" do
    create_crawl(max_pages: 0, requests_per_second: 50, scope: "everything")

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json["errors"].map { _1["field"] }).to include("max_pages", "requests_per_second", "scope")
  end

  it "requires accepting the site's terms for unverified domains and applies their limits" do
    rival = create(:domain, project:, host_input: "rival.com")
    post "/api/v1/projects/#{project.id}/crawls", params: { crawl: { domain_id: rival.id, max_pages: 200, requests_per_second: 0.5 } }, as: :json
    expect(json["errors"].map { _1["field"] }).to eq([ "terms_accepted" ])

    post "/api/v1/projects/#{project.id}/crawls",
      params: { crawl: { domain_id: rival.id, max_pages: 200, requests_per_second: 0.5, terms_accepted: true } }, as: :json
    expect(response).to have_http_status(:accepted)
    expect(Crawl.last.terms_accepted_at).to be_present
  end

  it "rejects a start URL whose host resolves to a private address" do
    SafeHttp.config.resolver = StubResolver.new("example.com" => [ "10.0.0.8" ])

    create_crawl

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json["errors"].first).to include("code" => "unsafe_target", "field" => "start_url")
  end

  it "allows only one active crawl per host" do
    create_crawl
    create_crawl

    expect(response).to have_http_status(:conflict)
    expect(json["errors"].first["code"]).to eq("crawl_in_progress")
  end

  it "pauses, resumes and cancels, rejecting invalid transitions" do
    create_crawl
    id = json.dig("data", "id")
    Crawl.find(id).update!(status: "running")

    post "/api/v1/crawls/#{id}/pause"
    expect(json.dig("data", "status")).to eq("paused")

    expect { post "/api/v1/crawls/#{id}/resume" }.to have_enqueued_job(Crawling::FetchLaneJob).at_least(:once)
    expect(json.dig("data", "status")).to eq("running")

    post "/api/v1/crawls/#{id}/cancel"
    expect(json.dig("data", "status")).to eq("cancelled")

    post "/api/v1/crawls/#{id}/resume"
    expect(response).to have_http_status(:conflict)
    expect(json["errors"].first["code"]).to eq("invalid_transition")
  end

  it "lists pages with filters and keyset pagination" do
    crawl = Crawl.create!(project:, domain:, config: { "start_url" => "https://example.com/" }, current_rps: 1, status: "completed")
    [ [ "/", 200 ], [ "/a", 404 ], [ "/b", 404 ], [ "/c", 500 ], [ "/d", nil ] ].each do |path, status|
      url = "https://example.com#{path}"
      cu = CrawlUrl.create!(crawl:, url:, url_hash: CrawlUrl.hash_url(url), source: "link", state: "done")
      Page.create!(crawl:, crawl_url: cu, url:, status_code: status, fetched_at: Time.current, fetch_error: status ? nil : "Timeout: x")
    end

    get "/api/v1/crawls/#{crawl.id}/pages", params: { filter: { status_code: "4xx" }, limit: 1 }
    expect(json["data"].map { _1["url"] }).to eq([ "https://example.com/a" ])
    cursor = json.dig("meta", "next_cursor")

    get "/api/v1/crawls/#{crawl.id}/pages", params: { filter: { status_code: "4xx" }, limit: 1, after: cursor }
    expect(json["data"].map { _1["url"] }).to eq([ "https://example.com/b" ])
    expect(json.dig("meta", "next_cursor")).to be_nil

    get "/api/v1/crawls/#{crawl.id}/pages", params: { filter: { status_code: "error" } }
    expect(json["data"].first).to include("url" => "https://example.com/d", "fetch_error" => "Timeout: x")

    get "/api/v1/crawls/#{crawl.id}"
    expect(json.dig("data", "status_codes")).to include("404" => 2, "error" => 1)
  end

  it "hides other users' crawls" do
    other = create(:project)
    other_domain = create(:domain, project: other)
    crawl = Crawl.create!(project: other, domain: other_domain, config: { "start_url" => "https://x.com/" }, current_rps: 1)

    get "/api/v1/crawls/#{crawl.id}"
    expect(response).to have_http_status(:not_found)
    post "/api/v1/crawls/#{crawl.id}/cancel"
    expect(response).to have_http_status(:not_found)
    get "/api/v1/crawls/#{crawl.id}/pages"
    expect(response).to have_http_status(:not_found)
    post "/api/v1/projects/#{other.id}/crawls", params: { crawl: { domain_id: other_domain.id } }, as: :json
    expect(response).to have_http_status(:not_found)
  end
end
