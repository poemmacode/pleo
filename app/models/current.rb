class Current < ActiveSupport::CurrentAttributes
  # A browser request has a session; an API request has the token's user.
  attribute :session, :api_user

  def user
    session ? session.user : api_user
  end
end
