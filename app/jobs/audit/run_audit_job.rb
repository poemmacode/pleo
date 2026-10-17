class Audit::RunAuditJob < ApplicationJob
  queue_as :audit

  def perform(crawl_id)
    crawl = Crawl.find_by(id: crawl_id)
    Audit::Runner.call(crawl) if crawl&.completed?
  end
end
