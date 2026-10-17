module CrawlSerializer
  def self.call(crawl, detail: false)
    data = {
      id: crawl.id,
      project_id: crawl.project_id,
      domain: { id: crawl.domain_id, host: crawl.domain.host, verified: crawl.domain.verified? },
      status: crawl.status,
      status_reason: crawl.status_reason,
      config: crawl.config,
      current_rps: crawl.current_rps,
      progress: {
        discovered: crawl.pages_discovered,
        crawled: crawl.pages_crawled,
        failed: crawl.pages_failed,
        skipped: crawl.pages_skipped,
        max_pages: crawl.crawl_config.max_pages
      },
      sitemap_status: crawl.sitemap_status,
      audit_status: crawl.audit_status,
      audited_at: crawl.audited_at,
      created_at: crawl.created_at,
      started_at: crawl.started_at,
      finished_at: crawl.finished_at
    }
    return data unless detail

    data.merge(
      skipped_by_reason: crawl.crawl_urls.where(state: "skipped").group(:skip_reason).count,
      status_codes: crawl.pages.group(:status_code).count.transform_keys { _1 || "error" },
      sitemaps: crawl.sitemaps,
      sitemap_urls_out_of_scope: crawl.sitemap_urls_out_of_scope,
      audit_error: crawl.audit_error,
      site_facts: crawl.site_facts,
      hosts: crawl.crawl_hosts.order(:host).map do |host|
        { host: host.host, robots_outcome: host.robots_outcome, robots_status: host.robots_status, crawl_delay: host.crawl_delay }
      end
    )
  end
end
