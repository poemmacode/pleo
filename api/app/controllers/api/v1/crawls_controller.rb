class Api::V1::CrawlsController < ApplicationController
  before_action :set_project, only: %i[index create]
  before_action :set_crawl, only: %i[show pause resume cancel]
  rate_limit to: 10, within: 1.minute, only: :create, store: RateLimitStore::STORE,
    with: -> { render_error(:too_many_requests, "rate_limited", "Demasiados crawls creados; espera un minuto") }

  def index
    crawls = @project.crawls.includes(:domain).order(created_at: :desc).limit(50)
    render json: { data: crawls.map { CrawlSerializer.call(_1) } }
  end

  def show
    render json: { data: CrawlSerializer.call(@crawl, detail: true) }
  end

  def create
    result = Crawling::CreateCrawl.new(@project, crawl_params).call
    if result.crawl
      render status: :accepted, json: { data: CrawlSerializer.call(result.crawl), links: { self: api_v1_crawl_path(result.crawl) } }
    else
      render status: result.status, json: { errors: result.errors }
    end
  end

  def pause = transition(Crawling::Lifecycle.pause(@crawl))

  def resume = transition(Crawling::Lifecycle.resume(@crawl))

  def cancel = transition(Crawling::Lifecycle.cancel(@crawl))

  private
    def transition(changed)
      if changed
        render json: { data: CrawlSerializer.call(@crawl.reload, detail: true) }
      else
        render_error(:conflict, "invalid_transition", "No se puede hacer eso con un crawl en estado #{@crawl.status}")
      end
    end

    def crawl_params
      params.require(:crawl).permit(
        :domain_id, :terms_accepted, :start_url, :scope, :max_pages, :max_depth, :requests_per_second, :device,
        :render_js, :use_sitemaps, :respect_nofollow, :store_html, include_patterns: [], exclude_patterns: []
      )
    end

    def set_project
      @project = Current.user.projects.find(params[:project_id])
    end

    def set_crawl
      @crawl = Crawl.joins(:project).where(projects: { user_id: Current.user.id }).find(params[:id])
    end
end
