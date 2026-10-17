require "rails_helper"

RSpec.describe "CSRF protection" do
  around do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  it "rejects form posts without a valid token" do
    create(:user, email: "ana@example.com")

    post session_path, params: { email: "ana@example.com", password: RequestHelpers::PASSWORD }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(Session.count).to eq(0)
  end
end
