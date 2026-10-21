class Api::V1::DomainsController < Api::V1::BaseController
  before_action :set_domain, only: %i[show verify destroy]
  rate_limit to: 10, within: 1.minute, only: :verify, store: RateLimitStore::STORE,
    by: -> { "verify:#{request.authorization}" }, with: -> { render_error(:too_many_requests, "rate_limited", "Too many verification attempts; wait a minute.") }

  def index
    project = accessible_projects.find(params[:project_id])
    render json: { data: project.domains.order(:host).map { ApiSerializer.domain(_1) } }
  end

  def show
    render json: { data: ApiSerializer.domain(@domain) }
  end

  def create
    project = accessible_projects.find(params[:project_id])
    domain = project.domains.new(host_input: params.require(:domain)[:host])
    return render_validation_errors(domain) unless domain.save

    render json: { data: ApiSerializer.domain(domain) }, status: :created
  end

  # Body: { "method": "dns_txt" | "html_file" | "meta" }
  def verify
    result = Domain::Verifier.new(@domain).call(params.require(:method))
    if result.success
      render json: { data: ApiSerializer.domain(@domain.reload) }
    else
      render_error(:unprocessable_entity, "verification_failed", result.detail.to_s)
    end
  end

  def destroy
    return unless authorize_destroy!(@domain)

    @domain.destroy!
    head :no_content
  end

  private
    def set_domain
      @domain = Domain.where(project: accessible_projects).find(params[:id])
    end
end
