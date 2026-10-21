require "rails_helper"

RSpec.describe "Registrations" do
  it "creates a member account and signs it in" do
    get new_registration_path
    expect(response).to have_http_status(:ok)

    post registration_path, params: { user: { email: "New@Example.com", password: RequestHelpers::PASSWORD,
                                              password_confirmation: RequestHelpers::PASSWORD, role: "admin" } }

    user = User.find_by!(email: "new@example.com")
    expect(user.role).to eq("member")
    expect(response).to redirect_to(projects_path)
    follow_redirect!
    expect(response.body).to include("Welcome!")
  end

  it "shows field errors" do
    create(:user, email: "taken@example.com")
    post registration_path, params: { user: { email: "taken@example.com", password: "short", password_confirmation: "other" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Email has already been taken", "Password is too short",
                                     "Password confirmation doesn&#39;t match Password")
  end

  it "can be closed with REGISTRATION_OPEN=false" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("REGISTRATION_OPEN", "true").and_return("false")

    get new_registration_path
    expect(response).to redirect_to(new_session_path)
    post registration_path, params: { user: { email: "x@example.com", password: RequestHelpers::PASSWORD } }
    expect(User.count).to eq(0)
  end

  it "rate limits sign-ups" do
    6.times { |i| post registration_path, params: { user: { email: "u#{i}@example.com", password: "x" } } }

    expect(response).to redirect_to(new_registration_path)
    expect(flash[:alert]).to include("Too many sign-ups")
  end
end
