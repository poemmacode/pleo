# Pages and frontier URLs of a crawl, with keyset pagination (?after=<id>&limit=).
class Api::V1::CrawlPagesController < ApplicationController
  include CrawlScoped

  before_action :set_crawl

  def index
    pages = @crawl.pages.order(:id)
    pages = filter_status(pages, params.dig(:filter, :status_code))
    pages = pages.where("url ILIKE ?", "%#{Page.sanitize_sql_like(params.dig(:filter, :url_contains))}%") if params.dig(:filter, :url_contains).present?
    paginate(pages) { PageSerializer.call(_1) }
  end

  def show
    page = @crawl.pages.find(params[:id])
    render json: { data: PageSerializer.call(page, detail: true) }
  end

  # Groups of pages sharing a title or description, or with near-identical text.
  def duplicates
    groups = case params[:type]
    when "title", "description"
      column = :"#{params[:type] == "title" ? "title" : "description"}_hash"
      @crawl.pages.where(indexable: true).where.not(column => nil).group_by(&column).values.select { _1.size > 1 }
    when "content"
      candidates = @crawl.pages.where(indexable: true).where.not(text_simhash: nil).where(word_count: Audit::Checks::Content::NearDuplicate::MIN_WORDS..)
      by_id = candidates.index_by(&:id)
      Audit::NearDuplicates.groups(candidates.map { [ _1.id, _1.text_simhash ] }).map { |ids| ids.map { by_id[_1] } }
    else
      return render_error(:bad_request, "invalid_type", "type debe ser title, description o content", field: "type")
    end
    data = groups.sort_by { -_1.size }.first(500).map do |pages|
      { size: pages.size, value: params[:type] == "description" ? pages.first.meta_description : pages.first.title,
        pages: pages.map { { id: _1.id, url: _1.url } } }
    end
    render json: { data: }
  end

  def urls
    urls = @crawl.crawl_urls.order(:id)
    urls = urls.where(state: params.dig(:filter, :state)) if params.dig(:filter, :state).present?
    urls = urls.where(skip_reason: params.dig(:filter, :skip_reason)) if params.dig(:filter, :skip_reason).present?
    paginate(urls) { _1.slice(:id, :url, :depth, :source, :in_sitemap, :state, :skip_reason, :attempts) }
  end

  private
    # "404", "4xx" or "error" (no HTTP response).
    def filter_status(scope, value)
      case value.to_s
      when /\A\d{3}\z/ then scope.where(status_code: value.to_i)
      when /\A([1-5])xx\z/ then scope.where(status_code: ($1.to_i * 100)..($1.to_i * 100 + 99))
      when "error" then scope.where(status_code: nil)
      else scope
      end
    end
end
