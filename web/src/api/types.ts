export type User = { id: number; email: string }

export type Domain = {
  id: number
  project_id: number
  host: string
  verified: boolean
  verified_at: string | null
  verification_method: string | null
  verification: {
    available_methods: string[]
    dns_txt: { name: string; type: 'TXT'; value: string }
    html_file: { url: string; content: string }
    meta: { tag: string }
    last_attempt_at: string | null
    last_error: string | null
  }
}

export type VerificationMethod = 'dns_txt' | 'html_file' | 'meta'

export type Project = {
  id: number
  name: string
  monthly_api_budget_cents: number
  domains: Domain[]
  created_at: string
}

export type Envelope<T> = { data: T; meta?: Record<string, unknown> }

export type CrawlStatus = 'queued' | 'running' | 'paused' | 'completed' | 'failed' | 'cancelled'

export type CrawlConfig = {
  start_url: string
  scope: 'domain' | 'subdomain' | 'subfolder'
  max_pages: number
  max_depth: number
  requests_per_second: number
  include_patterns: string[]
  exclude_patterns: string[]
  device: 'desktop' | 'mobile'
  use_sitemaps: boolean
  respect_nofollow: boolean
}

export type Crawl = {
  id: number
  project_id: number
  domain: { id: number; host: string; verified: boolean }
  status: CrawlStatus
  status_reason: string | null
  config: CrawlConfig
  current_rps: number
  progress: { discovered: number; crawled: number; failed: number; skipped: number; max_pages: number }
  sitemap_status: 'pending' | 'done' | 'skipped'
  audit_status: 'pending' | 'running' | 'done' | 'failed'
  audited_at: string | null
  audit_error?: string | null
  created_at: string
  started_at: string | null
  finished_at: string | null
  skipped_by_reason?: Record<string, number>
  status_codes?: Record<string, number>
  sitemaps?: { url: string; status: number | null; urls: number; added: number; out_of_scope: number; error: string | null }[]
  hosts?: { host: string; robots_outcome: string; robots_status: number | null; crawl_delay: number | null }[]
}

export type CrawlPage = {
  id: number
  url: string
  depth: number | null
  in_sitemap: boolean
  status_code: number | null
  redirect_url: string | null
  fetch_error: string | null
  content_type: string | null
  content_length: number | null
  truncated: boolean
  response_ms: number | null
}

export type Severity = 'error' | 'warning' | 'notice'

export type IssueSummary = {
  check_key: string
  category: string
  severity: Severity
  weight: number
  title: string
  description: string
  how_to_fix: string
  count: number
}

export type Finding = { id: number; page_id: number | null; url: string | null; details: Record<string, unknown> }

export type PageDetail = CrawlPage & {
  title: string | null
  indexable: boolean
  indexability_reason: string | null
  word_count: number | null
  inlinks_count: number
  internal_pagerank: number | null
  meta_description: string | null
  meta_robots: string | null
  x_robots_tag: string | null
  canonical: string | null
  canonical_hrefs: string[]
  lang: string | null
  viewport: string | null
  hreflang: { lang: string; href: string }[]
  h1: string[]
  headings: { level: number; text: string }[]
  images_count: number | null
  images_missing_alt: number | null
  structured_data: { syntax: string; types: string[]; valid_syntax: boolean; validation_errors: Record<string, string>[]; validation_warnings: Record<string, string>[] }[]
  issues: { check_key: string; severity: Severity; title: string; details: Record<string, unknown> }[]
  outlinks: { url: string; anchor: string | null; internal: boolean; rel: string[] }[]
  inlinks: { url: string; anchor: string | null }[]
}
