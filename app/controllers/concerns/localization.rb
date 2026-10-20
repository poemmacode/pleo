# Picks the interface language: the signed-in user's preference, else the one chosen on the login page
# (kept in the session), else English.
module Localization
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale
  end

  private
    def switch_locale(&action)
      I18n.with_locale(current_locale, &action)
    end

    def current_locale
      [ Current.user&.locale, session[:locale] ].find { valid_locale?(_1) } || I18n.default_locale
    end

    def valid_locale?(locale)
      locale.present? && I18n.available_locales.map(&:to_s).include?(locale.to_s)
    end
end
