class CrawlsController < ApplicationController
  include CrawlScoped

  FORM_FIELDS = %i[start_url scope max_pages max_depth requests_per_second device use_sitemaps respect_nofollow
                   include_patterns exclude_patterns terms_accepted run_pagespeed pagespeed_sample].freeze

  before_action :set_project, only: %i[new create]
  before_action :set_crawl, only: %i[show pause resume cancel audit]
  rate_limit to: 10, within: 1.minute, only: :create, store: RateLimitStore::STORE,
    with: -> { redirect_back_or_to root_path, alert: "Demasiados crawls creados; espera un minuto." }

  def new
    @domain = selected_domain
    @form = { use_sitemaps: true, run_pagespeed: true }
    redirect_to @project, alert: "Añade primero un dominio al proyecto." unless @domain
  end

  def create
    @domain = selected_domain
    result = Crawling::CreateCrawl.new(@project, crawl_params).call
    if result.crawl
      redirect_to result.crawl
    else
      @form = params.require(:crawl).permit(*FORM_FIELDS).to_h.symbolize_keys
      @errors = result.errors
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def pause = transition(Crawling::Lifecycle.pause(@crawl), "Crawl en pausa.")

  def resume = transition(Crawling::Lifecycle.resume(@crawl), "Crawl reanudado.")

  def cancel = transition(Crawling::Lifecycle.cancel(@crawl), "Crawl cancelado.")

  def audit
    if !@crawl.completed? || @crawl.audit_status == "running"
      return redirect_to @crawl, alert: "Solo se puede repetir la auditoría de un crawl completado.", status: :see_other
    end

    @crawl.update!(audit_status: "pending")
    Audit::RunAuditJob.perform_later(@crawl.id)
    Crawling::ProgressBroadcaster.call(@crawl, force: true)
    redirect_to @crawl, notice: "Auditoría en marcha.", status: :see_other
  end

  private
    def set_project
      @project = Current.user.projects.find(params[:project_id])
    end

    def selected_domain
      domain_id = params.dig(:crawl, :domain_id) || params[:domain_id]
      (domain_id && @project.domains.find_by(id: domain_id)) || @project.domains.min_by(&:host)
    end

    # Pattern textareas hold one regex per line.
    def crawl_params
      permitted = params.require(:crawl).permit(:domain_id, *FORM_FIELDS).to_h.symbolize_keys
      %i[include_patterns exclude_patterns].each do |key|
        permitted[key] = permitted[key].to_s.split("\n").map(&:strip).reject(&:empty?)
      end
      permitted
    end

    def transition(changed, notice)
      if changed
        Crawling::ProgressBroadcaster.call(@crawl.reload, force: true)
        redirect_to @crawl, notice:, status: :see_other
      else
        redirect_to @crawl, alert: "No se puede hacer eso con un crawl #{helpers.crawl_status_label(@crawl.status).downcase}.", status: :see_other
      end
    end
end
