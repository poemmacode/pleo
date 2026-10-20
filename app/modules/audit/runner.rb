module Audit
  # Runs the whole audit for a completed crawl: link graph, external links, PageRank, site facts,
  # then every check in the catalog. Re-running replaces the previous issues.
  module Runner
    INSERT_BATCH = 2_000

    module_function

    def call(crawl, check_external_links: true)
      crawl.update!(audit_status: "running", audit_error: nil)
      Crawling::ProgressBroadcaster.call(crawl, force: true)
      LinkGraph.build(crawl)
      ExternalLinkChecker.new(crawl).call if check_external_links
      PageRank.compute_for(crawl)
      Performance::Measure.call(crawl) # after PageRank: the sample favours important pages
      crawl.update!(site_facts: SiteFacts.collect(crawl))
      Catalog.sync_definitions!

      context = Context.new(crawl.reload)
      Issue.transaction do
        Issue.where(crawl_id: crawl.id).delete_all
        Catalog::CHECKS.each do |check_class|
          rows = check_class.new(context).findings.map do |finding|
            { crawl_id: crawl.id, check_key: check_class.key, page_id: finding.page_id, url: finding.url, details: finding.details }
          end
          rows.each_slice(INSERT_BATCH) { Issue.insert_all(_1) }
        end
      end
      Scoring.call(crawl)
      crawl.update!(audit_status: "done", audited_at: Time.current)
      Crawling::ProgressBroadcaster.call(crawl, force: true)
    rescue StandardError => e
      crawl.update_columns(audit_status: "failed", audit_error: "#{e.class}: #{e.message}".first(500))
      Crawling::ProgressBroadcaster.call(crawl, force: true)
      raise
    end
  end
end
