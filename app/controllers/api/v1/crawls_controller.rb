class Api::V1::CrawlsController < Api::V1::BaseController
  FIELDS = %i[domain_id start_url scope max_pages max_depth requests_per_second device use_sitemaps respect_nofollow
              terms_accepted run_pagespeed pagespeed_sample].freeze

  before_action :set_crawl, only: %i[show pause resume cancel]
  rate_limit to: 10, within: 1.minute, only: :create, store: RateLimitStore::STORE,
    by: -> { "crawl:#{request.authorization}" }, with: -> { render_error(:too_many_requests, "rate_limited", "Too many crawls started; wait a minute.") }

  def index
    project = accessible_projects.find(params[:project_id])
    records, next_cursor = keyset(project.crawls.includes(:domain).order(:id))
    render json: { data: records.map { ApiSerializer.crawl(_1) }, next_cursor: }
  end

  def show
    render json: { data: ApiSerializer.crawl(@crawl) }
  end

  def create
    project = accessible_projects.find(params[:project_id])
    crawl_params = params.require(:crawl)
    attributes = crawl_params.permit(*FIELDS, include_patterns: [], exclude_patterns: []).to_h.symbolize_keys
    result = Crawling::CreateCrawl.new(project, attributes).call
    if result.crawl
      render json: { data: ApiSerializer.crawl(result.crawl) }, status: :created
    else
      render json: { error: { code: result.errors.first[:code], message: "The crawl could not be started.", details: result.errors } },
             status: result.status
    end
  end

  def pause = transition(Crawling::Lifecycle.pause(@crawl))

  def resume = transition(Crawling::Lifecycle.resume(@crawl))

  def cancel = transition(Crawling::Lifecycle.cancel(@crawl))

  private
    def set_crawl
      @crawl = Crawl.where(project: accessible_projects).find(params[:id])
    end

    def transition(changed)
      return render_error(:conflict, "invalid_transition", "Not allowed while the crawl is #{@crawl.status}.") unless changed

      Crawling::ProgressBroadcaster.call(@crawl.reload, force: true)
      render json: { data: ApiSerializer.crawl(@crawl) }
    end
end
