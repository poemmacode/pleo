# Role checks (ADR 0011). Records outside the user's scope are already a 404 through accessible_projects;
# this covers what a member may see but not do.
module Authorization
  extend ActiveSupport::Concern

  class NotAuthorized < StandardError; end

  included do
    helper_method :can_destroy?
    rescue_from NotAuthorized, with: :not_authorized
  end

  private
    def can_destroy?(record) = Current.user&.can_destroy?(record)

    def authorize_destroy!(record)
      raise NotAuthorized unless can_destroy?(record)
    end

    def require_admin!
      raise NotAuthorized unless Current.user&.admin?
    end

    def not_authorized
      redirect_back_or_to projects_path, alert: t("authorization.denied"), status: :see_other
    end
end
