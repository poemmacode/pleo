require "rails_helper"

RSpec.describe "Sessions API" do
  let!(:user) { create(:user, email: "ana@example.com") }

  it "logs in with an HttpOnly, SameSite=Lax session cookie" do
    post "/api/v1/session", params: { email: "ANA@example.com", password: RequestHelpers::PASSWORD }, as: :json

    expect(response).to have_http_status(:created)
    expect(json["data"]).to eq("id" => user.id, "email" => "ana@example.com")
    expect(json.dig("meta", "csrf_token")).to be_present
    cookie = Array(response.headers["Set-Cookie"]).join("\n").lines.find { _1.start_with?("session_id=") }
    expect(cookie).to match(/httponly/i).and match(/samesite=lax/i)
  end

  it "rejects bad credentials without revealing which part was wrong" do
    post "/api/v1/session", params: { email: "ana@example.com", password: "wrong password!" }, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(json["errors"].first["code"]).to eq("invalid_credentials")
  end

  it "returns 401 on protected endpoints without a session" do
    get "/api/v1/session"
    expect(response).to have_http_status(:unauthorized)

    get "/api/v1/projects"
    expect(response).to have_http_status(:unauthorized)
    expect(json["errors"].first["code"]).to eq("unauthenticated")
  end

  it "logs out and revokes the server-side session" do
    sign_in(user)
    get "/api/v1/session"
    expect(response).to have_http_status(:ok)

    expect { delete "/api/v1/session" }.to change(Session, :count).by(-1)
    get "/api/v1/session"
    expect(response).to have_http_status(:unauthorized)
  end

  it "rate limits login attempts" do
    10.times { post "/api/v1/session", params: { email: "ana@example.com", password: "nope nope nope" }, as: :json }
    post "/api/v1/session", params: { email: "ana@example.com", password: RequestHelpers::PASSWORD }, as: :json

    expect(response).to have_http_status(:too_many_requests)
  end
end
