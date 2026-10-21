# Public sign-up. New accounts are always members; the admin only comes from ADMIN_EMAIL (ADR 0011).
class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  before_action :require_open_registration
  rate_limit to: 5, within: 1.hour, only: :create, store: RateLimitStore::STORE,
    with: -> { redirect_to new_registration_path, alert: t("registrations.rate_limited") }

  def self.open? = ENV.fetch("REGISTRATION_OPEN", "true") != "false"

  def new
    return redirect_to projects_path if authenticated?

    @user = User.new
  end

  def create
    @user = User.new(params.require(:user).permit(:email, :password, :password_confirmation))
    @user.role = "member"
    @user.locale = session[:locale] if valid_locale?(session[:locale])
    if @user.save
      reset_session
      start_new_session_for(@user)
      redirect_to projects_path, notice: t("registrations.welcome")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def require_open_registration
      redirect_to new_session_path, alert: t("registrations.closed") unless self.class.open?
    end
end
