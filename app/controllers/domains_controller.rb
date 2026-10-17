class DomainsController < ApplicationController
  before_action :set_domain, only: %i[destroy verify]
  rate_limit to: 10, within: 1.minute, only: :verify, store: RateLimitStore::STORE,
    with: -> { redirect_back_or_to root_path, alert: "Demasiados intentos de verificación; espera un minuto." }

  def create
    @project = Current.user.projects.find(params[:project_id])
    @domain = @project.domains.new(host_input: params.require(:domain)[:host])
    if @domain.save
      redirect_to @project, notice: "Dominio #{@domain.host} añadido. Verifícalo para poder rastrearlo completo."
    else
      render "projects/show", status: :unprocessable_entity
    end
  end

  def destroy
    @domain.destroy!
    redirect_to @domain.project, notice: "Dominio #{@domain.host} eliminado.", status: :see_other
  end

  def verify
    result = Domain::Verifier.new(@domain).call(params.require(:method))
    if result.success
      redirect_to @domain.project, notice: "#{@domain.host} verificado."
    else
      redirect_to @domain.project, alert: "#{@domain.host}: #{result.detail}"
    end
  end

  private
    def set_domain
      @domain = Domain.joins(:project).where(projects: { user_id: Current.user.id }).find(params[:id])
    end
end
