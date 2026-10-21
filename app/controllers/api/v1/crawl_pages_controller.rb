class Api::V1::CrawlPagesController < Api::V1::BaseController
  # ?status=200 | 4xx | error, plus keyset pagination.
  def index
    crawl = Crawl.where(project: accessible_projects).find(params[:crawl_id])
    records, next_cursor = keyset(crawl.pages.order(:id).with_status_filter(params[:status]))
    render json: { data: records.map { ApiSerializer.page(_1) }, next_cursor: }
  end
end
