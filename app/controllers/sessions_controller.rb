class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, store: RateLimitStore::STORE,
    with: -> { redirect_to new_session_path, alert: t("sessions.rate_limited") }

  def new
  end

  def create
    if (user = User.authenticate_by(params.permit(:email, :password)))
      return_to = after_authentication_url
      chosen_locale = session[:locale]
      # Rotate the Rails session (and with it the CSRF token) on login.
      reset_session
      start_new_session_for(user)
      # A language picked on the login page becomes the user's preference.
      user.update!(locale: chosen_locale) if valid_locale?(chosen_locale) && chosen_locale != user.locale
      redirect_to return_to
    else
      flash.now[:alert] = t("sessions.invalid_credentials")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_session
    reset_session
    redirect_to new_session_path, status: :see_other
  end
end
