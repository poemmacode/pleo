# Findings of one check, loaded into a lazy Turbo Frame when its <details> is opened.
class Crawls::IssuesController < ApplicationController
  include CrawlScoped

  before_action :set_crawl

  def show
    @definition = CheckDefinition.find_by!(key: params[:check_key])
    # Most important pages first (Audit::Scoring priority).
    @findings, @next_page = numbered(@crawl.issues.where(check_key: @definition.key).order("priority_score DESC NULLS LAST, id"))
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
