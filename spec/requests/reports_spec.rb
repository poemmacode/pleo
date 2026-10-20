require "rails_helper"

RSpec.describe "Reports (exports)" do
  include ActiveJob::TestHelper

  let(:crawl) { audit_crawl.tap { _1.update!(audit_status: "done") } }

  before do
    sign_in(crawl.project.user)
    Audit::Catalog.sync_definitions!
    audit_page("/")
  end

  it "generates a report in the background, keeping only the latest of each kind" do
    expect { post crawl_reports_path(crawl), params: { kind: "pages_csv" } }.to have_enqueued_job(Reports::GenerateReportJob)
    expect(response).to redirect_to(crawl_path(crawl))
    perform_enqueued_jobs { post crawl_reports_path(crawl), params: { kind: "pages_csv" } }

    report = crawl.reports.sole
    expect(report).to have_attributes(status: "done", filename: a_string_matching(/\Aseo-example\.com-\d{8}-pages\.csv\z/))

    get crawl_path(crawl)
    expect(response.body).to include("Pages (CSV)", crawl_report_path(crawl, report))
  end

  it "downloads a finished report as an attachment" do
    perform_enqueued_jobs { post crawl_reports_path(crawl), params: { kind: "xlsx" } }
    report = crawl.reports.sole

    get crawl_report_path(crawl, report)

    expect(response.media_type).to eq("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    expect(response.headers["Content-Disposition"]).to include("attachment", report.filename)
    expect(response.body.bytesize).to eq(report.byte_size)
  end

  it "refuses reports before the audit is done and unknown kinds" do
    crawl.update!(audit_status: "running")
    expect { post crawl_reports_path(crawl), params: { kind: "pdf" } }.not_to have_enqueued_job
    expect(flash[:alert]).to include("once the audit has finished")

    crawl.update!(audit_status: "done")
    post crawl_reports_path(crawl), params: { kind: "exe" }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "does not serve unfinished reports or other users' reports" do
    pending_report = crawl.reports.create!(kind: "pdf")
    get crawl_report_path(crawl, pending_report)
    expect(response).to redirect_to(crawl_path(crawl))

    done = crawl.reports.create!(kind: "pages_csv", status: "done", data: "x", byte_size: 1, filename: "x.csv", content_type: "text/csv")
    delete session_path
    sign_in(create(:user))
    get crawl_report_path(crawl, done)
    expect(response).to have_http_status(:not_found)
  end

  it "marks a report as failed when generation breaks" do
    allow(Reports::PagesCsv).to receive(:new).and_raise(RuntimeError, "boom")
    post crawl_reports_path(crawl), params: { kind: "pages_csv" }
    report = crawl.reports.sole

    expect { Reports::GenerateReportJob.perform_now(report.id) }.to raise_error(RuntimeError, "boom")
    expect(report.reload).to have_attributes(status: "failed", error: "RuntimeError: boom")
  end
end
