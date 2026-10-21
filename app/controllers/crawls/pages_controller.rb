class Crawls::PagesController < ApplicationController
  include CrawlScoped

  before_action :set_crawl

  # HTML: the filterable table inside the "pages" Turbo Frame. Turbo Stream: "load more" rows.
  def index
    @status = params[:status].to_s
    @pages, @next_cursor = keyset(@crawl.pages.order(:id).with_status_filter(@status))
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    @page = @crawl.pages.find(params[:id])
    @issues = @page.issues.joins(:check_definition).order("check_definitions.weight DESC")
      .pluck(:check_key, "check_definitions.severity", :details)
    @outlinks = @page.links.order(:id).limit(200)
    @inlinks = Link.where(to_page_id: @page.id).joins(:from_page).order("pages.id").limit(200).pluck("pages.url", :anchor)
  end
end
