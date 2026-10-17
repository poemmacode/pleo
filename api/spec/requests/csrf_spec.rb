require "rails_helper"

RSpec.describe "CSRF protection" do
  around do |example|
    original = ApplicationController.allow_forgery_protection
    ApplicationController.allow_forgery_protection = true
    example.run
  ensure
    ApplicationController.allow_forgery_protection = original
  end

  let(:user) { create(:user) }

  it "rejects state-changing requests without the token" do
    get "/api/v1/csrf_token"
    token = json.dig("data", "token")
    post "/api/v1/session", params: { email: user.email, password: RequestHelpers::PASSWORD }, as: :json,
      headers: { "X-CSRF-Token" => token }
    expect(response).to have_http_status(:created)

    post "/api/v1/projects", params: { project: { name: "Sin token" } }, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(json["errors"].first["code"]).to eq("invalid_csrf_token")

    post "/api/v1/projects", params: { project: { name: "Con token" } }, as: :json,
      headers: { "X-CSRF-Token" => json_token_after_login }
    expect(response).to have_http_status(:created)
  end

  def json_token_after_login
    get "/api/v1/csrf_token"
    json.dig("data", "token")
  end
end
