class DomainsController < ApplicationController
  before_action :set_domain, only: %i[destroy verify]
  rate_limit to: 10, within: 1.minute, only: :verify, store: RateLimitStore::STORE,
    with: -> { redirect_back_or_to projects_path, alert: t("domains.flash.rate_limited") }

  def create
    @project = Current.user.accessible_projects.find(params[:project_id])
    @domain = @project.domains.new(host_input: params.require(:domain)[:host])
    if @domain.save
      redirect_to @project, notice: t("domains.flash.added", host: @domain.host)
    else
      render "projects/show", status: :unprocessable_entity
    end
  end

  def destroy
    authorize_destroy!(@domain)
    @domain.destroy!
    redirect_to @domain.project, notice: t("domains.flash.removed", host: @domain.host), status: :see_other
  end

  def verify
    result = Domain::Verifier.new(@domain).call(params.require(:method))
    if result.success
      redirect_to @domain.project, notice: t("domains.flash.verified", host: @domain.host)
    else
      redirect_to @domain.project, alert: t("domains.flash.verification_failed", host: @domain.host, detail: result.detail)
    end
  end

  private
    def set_domain
      @domain = Domain.where(project: Current.user.accessible_projects).find(params[:id])
    end
end
