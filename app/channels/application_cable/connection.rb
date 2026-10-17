module ApplicationCable
  # WebSocket connections need the same server-side session as the pages; anonymous ones are refused.
  # Turbo signs stream names, so a user can only subscribe to streams rendered into their own pages.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = Session.find_by(id: cookies.signed[Authentication::SESSION_COOKIE])&.user || reject_unauthorized_connection
    end
  end
end
