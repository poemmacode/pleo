module RequestHelpers
  PASSWORD = "correct horse battery".freeze

  def json
    JSON.parse(response.body)
  end

  def sign_in(user)
    post "/api/v1/session", params: { email: user.email, password: PASSWORD }, as: :json
    expect(response).to have_http_status(:created)
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
  config.before(type: :request) { RateLimitStore::STORE.clear }
end
