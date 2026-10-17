class Api::V1::DomainsController < ApplicationController
  before_action :set_project, only: %i[index create]
  before_action :set_domain, only: %i[show destroy verify]
  rate_limit to: 10, within: 1.minute, only: :verify, store: RateLimitStore::STORE,
    with: -> { render_error(:too_many_requests, "rate_limited", "Demasiados intentos de verificación") }

  def index
    render json: { data: @project.domains.order(:host).map { DomainSerializer.call(_1) } }
  end

  def show
    render json: { data: DomainSerializer.call(@domain) }
  end

  def create
    domain = @project.domains.new(host_input: params.require(:domain).require(:host))
    if domain.save
      render status: :created, json: { data: DomainSerializer.call(domain) }
    else
      render_validation_errors(domain)
    end
  end

  def destroy
    @domain.destroy!
    head :no_content
  end

  def verify
    result = Domain::Verifier.new(@domain).call(params.require(:method))
    if result.success
      render json: { data: DomainSerializer.call(@domain) }
    else
      render_error(:unprocessable_entity, result.code, result.detail, field: "method")
    end
  end

  private
    def set_project
      @project = Current.user.projects.find(params[:project_id])
    end

    def set_domain
      @domain = Domain.joins(:project).where(projects: { user_id: Current.user.id }).find(params[:id])
    end
end
