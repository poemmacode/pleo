require "rails_helper"

RSpec.describe "API tokens settings" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "shows a new token once, stores only its digest and revokes it" do
    post settings_api_tokens_path, params: { api_token: { name: "CI" } }
    follow_redirect!
    token = response.body[/seop_[1-9A-HJ-NP-Za-km-z]{40}/]
    expect(token).to be_present

    record = user.api_tokens.sole
    expect(record.token_digest).to eq(ApiToken.digest(token))
    expect(ApiToken.authenticate(token)).to eq(record)

    get settings_api_tokens_path
    expect(response.body).not_to include(token)
    expect(response.body).to include(record.token_prefix)

    delete settings_api_token_path(record)
    expect(ApiToken.authenticate(token)).to be_nil
  end

  it "does not touch other users' tokens" do
    foreign = create(:user).api_tokens.create!(name: "theirs")

    delete settings_api_token_path(foreign)
    expect(response).to have_http_status(:not_found)
  end
end
