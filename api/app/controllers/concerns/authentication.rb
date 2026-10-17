module Authentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = :session_id

  included do
    before_action :require_authentication
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def require_authentication
      resume_session || render_error(:unauthorized, "unauthenticated", "Inicia sesión para continuar")
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[SESSION_COOKIE]) if cookies.signed[SESSION_COOKIE]
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent&.first(255), ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[SESSION_COOKIE] = {
          value: session.id, httponly: true, same_site: :lax, secure: Rails.env.production?
        }
      end
    end

    def terminate_session
      Current.session&.destroy
      cookies.delete(SESSION_COOKIE)
    end
end
