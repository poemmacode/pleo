# Groups of indexable pages sharing a title or description, or with near-identical text.
class Crawls::DuplicatesController < ApplicationController
  include CrawlScoped

  before_action :set_crawl

  def index
    @type = Audit::Duplicates::TYPES.include?(params[:type]) ? params[:type] : "title"
    @groups = Audit::Duplicates.groups(@crawl, @type)
  end
end
