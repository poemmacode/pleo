# Pages and frontier URLs of a crawl, with keyset pagination (?after=<id>&limit=).
class Api::V1::CrawlPagesController < ApplicationController
  MAX_LIMIT = 200

  before_action :set_crawl

  def index
    pages = @crawl.pages.order(:id)
    pages = filter_status(pages, params.dig(:filter, :status_code))
    pages = pages.where("url ILIKE ?", "%#{Page.sanitize_sql_like(params.dig(:filter, :url_contains))}%") if params.dig(:filter, :url_contains).present?
    paginate(pages) { PageSerializer.call(_1) }
  end

  def urls
    urls = @crawl.crawl_urls.order(:id)
    urls = urls.where(state: params.dig(:filter, :state)) if params.dig(:filter, :state).present?
    urls = urls.where(skip_reason: params.dig(:filter, :skip_reason)) if params.dig(:filter, :skip_reason).present?
    paginate(urls) { _1.slice(:id, :url, :depth, :source, :in_sitemap, :state, :skip_reason, :attempts) }
  end

  private
    def set_crawl
      @crawl = Crawl.joins(:project).where(projects: { user_id: Current.user.id }).find(params[:crawl_id])
    end

    # "404", "4xx" or "error" (no HTTP response).
    def filter_status(scope, value)
      case value.to_s
      when /\A\d{3}\z/ then scope.where(status_code: value.to_i)
      when /\A([1-5])xx\z/ then scope.where(status_code: ($1.to_i * 100)..($1.to_i * 100 + 99))
      when "error" then scope.where(status_code: nil)
      else scope
      end
    end

    def paginate(scope)
      limit = params.fetch(:limit, 50).to_i.clamp(1, MAX_LIMIT)
      scope = scope.where("#{scope.table_name}.id > ?", params[:after].to_i) if params[:after].present?
      records = scope.limit(limit + 1).to_a
      more = records.size > limit
      records = records.first(limit)
      render json: { data: records.map { yield _1 }, meta: { next_cursor: more ? records.last.id : nil } }
    end
end
