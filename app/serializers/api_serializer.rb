# JSON shapes of the API (kept in sync with docs/api/openapi.yaml by spec/requests/api/openapi_spec.rb).
module ApiSerializer
  module_function

  def user(user)
    { id: user.id, email: user.email, role: user.role, locale: user.locale, created_at: user.created_at }
  end

  def project(project)
    { id: project.id, name: project.name, owner_id: project.user_id, domains_count: project.domains.size,
      created_at: project.created_at, updated_at: project.updated_at }
  end

  def domain(domain)
    { id: domain.id, project_id: domain.project_id, host: domain.host, verified: domain.verified?,
      verified_at: domain.verified_at, verification_method: domain.verification_method,
      verification: {
        dns_txt: { type: "TXT", name: domain.host, value: domain.txt_record_value },
        html_file: { url: "https://#{domain.host}#{Domain::Verifier.file_path(domain)}", content: domain.txt_record_value },
        meta: { tag: Domain::Verifier.meta_tag(domain) }
      },
      created_at: domain.created_at }
  end

  def crawl(crawl)
    config = crawl.crawl_config
    { id: crawl.id, project_id: crawl.project_id, domain_id: crawl.domain_id, host: crawl.domain.host,
      status: crawl.status, status_reason: crawl.status_reason,
      config: { start_url: config.start_url, scope: config.scope, max_pages: config.max_pages, max_depth: config.max_depth,
                requests_per_second: config.requests_per_second, device: config.device },
      pages: { discovered: crawl.pages_discovered, crawled: crawl.pages_crawled, failed: crawl.pages_failed, skipped: crawl.pages_skipped },
      audit_status: crawl.audit_status, health_score: crawl.health_score&.round(1), category_scores: crawl.category_scores,
      started_at: crawl.started_at, finished_at: crawl.finished_at, created_at: crawl.created_at }
  end

  def page(page)
    { id: page.id, url: page.url, status_code: page.status_code, depth: page.depth, redirect_url: page.redirect_url,
      fetch_error: page.fetch_error, content_type: page.content_type, response_ms: page.response_ms,
      title: page.title, meta_description: page.meta_description, canonical: page.canonical,
      indexable: page.indexable, indexability_reason: page.indexability_reason, in_sitemap: page.in_sitemap }
  end

  def issue(entry)
    { check_key: entry.check_key, category: entry.category, severity: entry.severity, title: entry.title,
      count: entry.count, priority: entry.priority }
  end
end
