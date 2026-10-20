# Switches the interface language and remembers it on the user (or the session before login).
class LocalesController < ApplicationController
  allow_unauthenticated_access

  def update
    locale = params.require(:locale).to_s
    return head :unprocessable_entity unless valid_locale?(locale)

    session[:locale] = locale
    resume_session&.user&.update!(locale:)
    redirect_back_or_to root_path, status: :see_other
  end
end
