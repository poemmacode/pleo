class Api::V1::CrawlIssuesController < ApplicationController
  include CrawlScoped

  SEVERITY_ORDER = %w[error warning notice].freeze

  before_action :set_crawl

  # One entry per check with findings, most severe first.
  def index
    counts = @crawl.issues.group(:check_key).count
    definitions = CheckDefinition.where(key: counts.keys).index_by(&:key)
    data = counts.filter_map do |key, count|
      definition = definitions[key]
      definition && IssueSerializer.summary(definition, count)
    end
    data.sort_by! { [ SEVERITY_ORDER.index(_1[:severity]), -_1[:weight], -_1[:count] ] }
    render json: {
      data:,
      meta: { audit_status: @crawl.audit_status, audited_at: @crawl.audited_at,
              by_severity: SEVERITY_ORDER.index_with { |s| data.select { _1[:severity] == s }.sum { _1[:count] } } }
    }
  end

  def show
    definition = CheckDefinition.find_by!(key: params[:check_key])
    scope = @crawl.issues.where(check_key: definition.key).order(:id)
    paginate(scope) { _1.slice(:id, :page_id, :url, :details) }
  end

  def rerun
    return render_error(:conflict, "crawl_not_completed", "El crawl debe estar completado") unless @crawl.completed?
    return render_error(:conflict, "audit_running", "La auditoría ya está en curso") if @crawl.audit_status == "running"

    @crawl.update!(audit_status: "pending")
    Audit::RunAuditJob.perform_later(@crawl.id)
    head :accepted
  end
end
