class Reports::GenerateReportJob < ApplicationJob
  queue_as :reports

  GENERATORS = {
    "pages_csv" => -> { Reports::PagesCsv }, "issues_csv" => -> { Reports::IssuesCsv },
    "xlsx" => -> { Reports::Workbook }, "pdf" => -> { Reports::ExecutiveSummary }
  }.freeze

  def perform(report_id)
    report = Report.find_by(id: report_id)
    return unless report

    data = GENERATORS.fetch(report.kind).call.new(report.crawl).render
    report.update!(status: "done", data:, byte_size: data.bytesize, filename: report.default_filename,
                   content_type: Report::KINDS.fetch(report.kind)[:content_type], generated_at: Time.current, error: nil)
  rescue StandardError => e
    report&.update_columns(status: "failed", error: "#{e.class}: #{e.message}".first(300))
    raise
  ensure
    Reports::Broadcaster.call(report.crawl) if report
  end
end
