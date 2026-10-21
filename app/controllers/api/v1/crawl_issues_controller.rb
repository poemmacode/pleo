class Api::V1::CrawlIssuesController < Api::V1::BaseController
  # Issue counts per check, highest priority first, once the audit is done.
  def index
    crawl = Crawl.where(project: accessible_projects).find(params[:crawl_id])
    summary = Audit::Summary.new(crawl)
    render json: { audit_status: crawl.audit_status, health_score: crawl.health_score&.round(1),
                   by_severity: summary.by_severity, data: summary.entries.map { ApiSerializer.issue(_1) } }
  end
end
