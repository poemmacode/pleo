# Export files of a crawl. Generated in the background; only the crawl's owner can download them.
class Crawls::ReportsController < ApplicationController
  include CrawlScoped

  before_action :set_crawl

  def create
    kind = params.require(:kind)
    return head :unprocessable_entity unless Report::KINDS.key?(kind)
    unless @crawl.audit_status == "done"
      return redirect_to @crawl, alert: t("reports.flash.audit_not_done"), status: :see_other
    end

    @crawl.reports.where(kind:).delete_all # keep only the latest of each kind
    report = @crawl.reports.create!(kind:, locale: I18n.locale)
    Reports::GenerateReportJob.perform_later(report.id)
    Reports::Broadcaster.call(@crawl)
    redirect_to @crawl, notice: t("reports.flash.generating", report: t("reports.kinds.#{kind}")), status: :see_other
  end

  def show
    report = @crawl.reports.find(params[:id])
    return redirect_to @crawl, alert: t("reports.flash.not_ready"), status: :see_other unless report.done?

    send_data report.data, filename: report.filename, type: report.content_type, disposition: "attachment"
  end
end
