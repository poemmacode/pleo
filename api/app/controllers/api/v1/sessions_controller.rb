class Api::V1::SessionsController < ApplicationController
  allow_unauthenticated_access only: :create
  rate_limit to: 10, within: 3.minutes, only: :create, store: RateLimitStore::STORE,
    with: -> { render_error(:too_many_requests, "rate_limited", "Demasiados intentos; espera unos minutos") }

  def show
    render json: { data: UserSerializer.call(Current.user) }
  end

  def create
    user = User.authenticate_by(email: params.require(:email), password: params.require(:password))
    if user
      # Rotate the Rails session (and with it the CSRF secret) on login.
      reset_session
      start_new_session_for(user)
      render status: :created, json: { data: UserSerializer.call(user), meta: { csrf_token: form_authenticity_token } }
    else
      render_error(:unauthorized, "invalid_credentials", "Correo o contraseña incorrectos")
    end
  end

  def destroy
    terminate_session
    reset_session
    head :no_content
  end
end
