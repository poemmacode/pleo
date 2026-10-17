module RequestHelpers
  PASSWORD = "correct horse battery".freeze

  def sign_in(user)
    post session_path, params: { email: user.email, password: PASSWORD }
    expect(response).to redirect_to(root_url)
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
  config.before(type: :request) { RateLimitStore::STORE.clear }
end
