require "rails_helper"

RSpec.describe "Projects API" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "creates, lists, updates and deletes the user's projects" do
    post "/api/v1/projects", params: { project: { name: "  Blog personal " } }, as: :json
    expect(response).to have_http_status(:created)
    id = json.dig("data", "id")
    expect(json.dig("data", "name")).to eq("Blog personal")

    get "/api/v1/projects"
    expect(json["data"].map { _1["id"] }).to eq([ id ])

    patch "/api/v1/projects/#{id}", params: { project: { name: "Blog" } }, as: :json
    expect(json.dig("data", "name")).to eq("Blog")

    delete "/api/v1/projects/#{id}"
    expect(response).to have_http_status(:no_content)
    expect(Project.exists?(id)).to be(false)
  end

  it "returns validation errors in the error envelope" do
    post "/api/v1/projects", params: { project: { name: "" } }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json["errors"].first).to include("code" => "invalid", "field" => "name")
  end

  it "hides other users' projects" do
    other = create(:project)

    get "/api/v1/projects/#{other.id}"
    expect(response).to have_http_status(:not_found)

    delete "/api/v1/projects/#{other.id}"
    expect(response).to have_http_status(:not_found)
    expect(Project.exists?(other.id)).to be(true)
  end
end
