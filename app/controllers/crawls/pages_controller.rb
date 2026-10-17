class Crawls::PagesController < ApplicationController
  include CrawlScoped

  before_action :set_crawl

  # HTML: the filterable table inside the "pages" Turbo Frame. Turbo Stream: "load more" rows.
  def index
    @status = params[:status].to_s
    @pages, @next_cursor = keyset(filter_status(@crawl.pages.order(:id), @status))
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    @page = @crawl.pages.find(params[:id])
    @issues = @page.issues.joins(:check_definition).order("check_definitions.weight DESC")
      .pluck(:check_key, "check_definitions.severity", "check_definitions.title", :details)
    @outlinks = @page.links.order(:id).limit(200)
    @inlinks = Link.where(to_page_id: @page.id).joins(:from_page).order("pages.id").limit(200).pluck("pages.url", :anchor)
  end

  private
    # "404", "4xx" or "error" (no HTTP response).
    def filter_status(scope, value)
      case value
      when /\A\d{3}\z/ then scope.where(status_code: value.to_i)
      when /\A([1-5])xx\z/ then scope.where(status_code: ($1.to_i * 100)..($1.to_i * 100 + 99))
      when "error" then scope.where(status_code: nil)
      else scope
      end
    end
end
