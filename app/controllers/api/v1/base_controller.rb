# JSON API v1 (docs/api/openapi.yaml). Authenticates with "Authorization: Bearer <token>" from
# Settings → API tokens and applies the same roles and ownership rules as the web interface.
class Api::V1::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  RATE_LIMIT = 120 # requests per minute and token

  before_action :authenticate_token!
  around_action :english_errors
  rate_limit to: RATE_LIMIT, within: 1.minute, store: RateLimitStore::STORE,
    by: -> { request.authorization.to_s }, with: -> { render_error(:too_many_requests, "rate_limited", "Too many requests; slow down.") }

  rescue_from ActiveRecord::RecordNotFound, with: -> { render_error(:not_found, "not_found", "Resource not found.") }
  rescue_from ActionController::ParameterMissing do |e|
    render_error(:bad_request, "parameter_missing", e.message)
  end

  private
    def authenticate_token!
      token = authenticate_with_http_token { |value, _options| ApiToken.authenticate(value) }
      return Current.api_user = token.user if token

      render_error(:unauthorized, "unauthorized", "Missing or invalid API token.")
    end

    # Error messages and validation errors are in English, whatever the account's interface language.
    def english_errors(&) = I18n.with_locale(:en, &)

    def accessible_projects = Current.user.accessible_projects

    def authorize_destroy!(record)
      return true if Current.user.can_destroy?(record)

      render_error(:forbidden, "forbidden", "Your role cannot delete this resource.")
      false
    end

    def render_error(status, code, message, details: nil)
      render json: { error: { code:, message:, details: }.compact }, status:
    end

    def render_validation_errors(record)
      details = record.errors.map { |e| { field: e.attribute.to_s, message: e.full_message } }
      render_error(:unprocessable_entity, "validation_failed", "Validation failed.", details:)
    end

    # Keyset pagination: ?after=<next_cursor>&limit=<1..200>.
    def keyset(scope)
      limit = params.fetch(:limit, 50).to_i.clamp(1, 200)
      scope = scope.where("#{scope.table_name}.id > ?", params[:after].to_i) if params[:after].present?
      records = scope.limit(limit + 1).to_a
      more = records.size > limit
      records = records.first(limit)
      [ records, more ? records.last.id : nil ]
    end
end
