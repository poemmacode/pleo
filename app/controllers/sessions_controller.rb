class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, store: RateLimitStore::STORE,
    with: -> { redirect_to new_session_path, alert: "Demasiados intentos; espera unos minutos." }

  def new
  end

  def create
    if (user = User.authenticate_by(params.permit(:email, :password)))
      return_to = after_authentication_url
      # Rotate the Rails session (and with it the CSRF token) on login.
      reset_session
      start_new_session_for(user)
      redirect_to return_to
    else
      flash.now[:alert] = "Correo o contraseña incorrectos."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_session
    reset_session
    redirect_to new_session_path, status: :see_other
  end
end
