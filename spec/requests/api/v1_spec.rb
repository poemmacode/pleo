require "rails_helper"

RSpec.describe "API v1" do
  let(:user) { create(:user) }
  let(:token) { user.api_tokens.create!(name: "test").token }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  def json = JSON.parse(response.body)

  it "rejects requests without a valid token" do
    get "/api/v1/me"
    expect(response).to have_http_status(:unauthorized)
    expect(json.dig("error", "code")).to eq("unauthorized")

    get "/api/v1/me", headers: { "Authorization" => "Bearer seop_wrong" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "identifies the token's user and records its use" do
    get "/api/v1/me", headers: headers

    expect(json["data"]).to include("email" => user.email, "role" => "member")
    expect(user.api_tokens.first.last_used_at).to be_present
  end

  it "creates, lists, renames and refuses to delete projects for a member" do
    post "/api/v1/projects", params: { project: { name: "Blog" } }, headers:, as: :json
    expect(response).to have_http_status(:created)
    id = json.dig("data", "id")

    post "/api/v1/projects", params: { project: { name: "" } }, headers:, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(json.dig("error", "details", 0, "field")).to eq("name")

    patch "/api/v1/projects/#{id}", params: { project: { name: "Company blog" } }, headers:, as: :json
    expect(json.dig("data", "name")).to eq("Company blog")

    get "/api/v1/projects", headers: headers
    expect(json["data"].map { _1["id"] }).to eq([ id ])
    expect(json["next_cursor"]).to be_nil

    delete "/api/v1/projects/#{id}", headers: headers
    expect(response).to have_http_status(:forbidden)
    expect(Project.exists?(id)).to be(true)
  end

  it "hides other users' records" do
    foreign = create(:project)
    domain = create(:domain, project: foreign)

    get "/api/v1/projects/#{foreign.id}", headers: headers
    expect(response).to have_http_status(:not_found)
    get "/api/v1/domains/#{domain.id}", headers: headers
    expect(response).to have_http_status(:not_found)
    post "/api/v1/projects/#{foreign.id}/crawls", params: { crawl: { domain_id: domain.id } }, headers:, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it "lets the admin delete any project" do
    admin_token = create(:user, :admin).api_tokens.create!(name: "admin").token
    project = create(:project)

    delete "/api/v1/projects/#{project.id}", headers: { "Authorization" => "Bearer #{admin_token}" }
    expect(response).to have_http_status(:no_content)
    expect(Project.exists?(project.id)).to be(false)
  end

  it "adds domains with verification instructions and only removes unverified, uncrawled ones" do
    project = create(:project, user:)

    post "/api/v1/projects/#{project.id}/domains", params: { domain: { host: "https://Example.com/" } }, headers:, as: :json
    expect(response).to have_http_status(:created)
    expect(json["data"]).to include("host" => "example.com", "verified" => false)
    expect(json.dig("data", "verification", "dns_txt", "value")).to start_with("seo-platform-verify=")

    post "/api/v1/projects/#{project.id}/domains", params: { domain: { host: "10.0.0.1" } }, headers:, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    verified = create(:domain, project:, host_input: "example.org", verified_at: Time.current)
    delete "/api/v1/domains/#{verified.id}", headers: headers
    expect(response).to have_http_status(:forbidden)

    delete "/api/v1/domains/#{project.domains.find_by!(host: "example.com").id}", headers: headers
    expect(response).to have_http_status(:no_content)
  end

  it "starts crawls through the same validation as the web form" do
    project = create(:project, user:)
    domain = create(:domain, project:, host_input: "example.com")

    post "/api/v1/projects/#{project.id}/crawls", params: { crawl: { domain_id: domain.id, max_pages: 100 } }, headers:, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(json.dig("error", "details").map { _1["field"] }).to include("terms_accepted")

    allow_any_instance_of(SafeHttp::Client).to receive(:preflight!)
    post "/api/v1/projects/#{project.id}/crawls", params: { crawl: { domain_id: domain.id, max_pages: 100, terms_accepted: true } },
         headers:, as: :json
    expect(response).to have_http_status(:created)
    crawl_id = json.dig("data", "id")
    expect(json["data"]).to include("status" => "queued", "host" => "example.com")
    expect(json.dig("data", "config", "max_pages")).to eq(100)

    post "/api/v1/crawls/#{crawl_id}/resume", headers: headers
    expect(response).to have_http_status(:conflict)
    post "/api/v1/crawls/#{crawl_id}/cancel", headers: headers
    expect(json.dig("data", "status")).to eq("cancelled")
  end

  it "lists pages with filters and keyset pagination, and the issue summary" do
    project = create(:project, user:)
    domain = create(:domain, project:, host_input: "example.com")
    crawl = Crawl.create!(project:, domain:, config: { "start_url" => "https://example.com/" }, current_rps: 1,
                          status: "completed", audit_status: "done", health_score: 81.26)
    [ 200, 404, 200 ].each_with_index do |code, i|
      url = "https://example.com/#{i}"
      crawl_url = CrawlUrl.create!(crawl:, url:, url_hash: CrawlUrl.hash_url(url), source: "link", state: "done")
      crawl.pages.create!(crawl_url:, url:, status_code: code, fetched_at: Time.current)
    end

    get "/api/v1/crawls/#{crawl.id}/pages", params: { limit: 2 }, headers: headers
    expect(json["data"].size).to eq(2)
    get "/api/v1/crawls/#{crawl.id}/pages", params: { limit: 2, after: json["next_cursor"] }, headers: headers
    expect(json["data"].size).to eq(1)
    expect(json["next_cursor"]).to be_nil

    get "/api/v1/crawls/#{crawl.id}/pages", params: { status: "4xx" }, headers: headers
    expect(json["data"].map { _1["status_code"] }).to eq([ 404 ])

    get "/api/v1/crawls/#{crawl.id}/issues", headers: headers
    expect(json).to include("audit_status" => "done", "health_score" => 81.3, "data" => [])
  end

  it "rate limits each token" do
    stub_const("Api::V1::BaseController::RATE_LIMIT", 120)
    121.times { get "/api/v1/me", headers: headers }

    expect(response).to have_http_status(:too_many_requests)
    expect(json.dig("error", "code")).to eq("rate_limited")
  end
end
