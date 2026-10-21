# Each user manages their own API tokens. Revoking a token is always allowed: it is a security control,
# not a data deletion.
class Settings::ApiTokensController < ApplicationController
  MAX_TOKENS = 10

  def index
    @tokens = Current.user.api_tokens.order(:created_at)
    @token = ApiToken.new
  end

  def create
    @token = Current.user.api_tokens.new(name: params.require(:api_token)[:name])
    if Current.user.api_tokens.count >= MAX_TOKENS
      @token.errors.add(:base, t("settings.api_tokens.flash.limit", count: MAX_TOKENS))
    elsif @token.save
      # Shown once: only the digest is stored.
      flash[:new_token] = @token.token
      return redirect_to settings_api_tokens_path, notice: t("settings.api_tokens.flash.created"), status: :see_other
    end
    @tokens = Current.user.api_tokens.order(:created_at)
    render :index, status: :unprocessable_entity
  end

  def destroy
    token = Current.user.api_tokens.find(params[:id])
    authorize_destroy!(token)
    token.destroy!
    redirect_to settings_api_tokens_path, notice: t("settings.api_tokens.flash.revoked", name: token.name), status: :see_other
  end
end
