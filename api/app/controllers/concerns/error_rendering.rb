# Uniform error envelope: { errors: [{ code, detail, field }] }.
module ErrorRendering
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound do
      render_error(:not_found, "not_found", "Recurso no encontrado")
    end
    rescue_from ActionController::ParameterMissing do |e|
      render_error(:bad_request, "parameter_missing", "Falta el parámetro #{e.param}", field: e.param.to_s)
    end
    rescue_from ActionController::InvalidAuthenticityToken do
      render_error(:forbidden, "invalid_csrf_token", "Token CSRF ausente o inválido")
    end
  end

  private
    def render_error(status, code, detail, field: nil)
      render status:, json: { errors: [ { code:, detail:, field: }.compact ] }
    end

    def render_validation_errors(record)
      errors = record.errors.map do |error|
        { code: "invalid", detail: error.full_message, field: error.attribute.to_s.delete_suffix("_input") }
      end
      render status: :unprocessable_entity, json: { errors: }
    end
end
