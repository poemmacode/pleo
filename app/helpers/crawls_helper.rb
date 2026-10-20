module CrawlsHelper
  PAGE_STATUS_FILTERS = [ "", "2xx", "3xx", "4xx", "5xx", "error" ].freeze

  def crawl_status_label(status) = t("crawls.statuses.#{status}", default: status.to_s)
  def crawl_reason_label(reason) = t("crawls.reasons.#{reason}", default: reason.to_s)
  def skip_reason_label(reason) = t("crawls.skip_reasons.#{reason}", default: reason.to_s)
  def robots_outcome_label(outcome) = t("crawls.robots_outcomes.#{outcome}", default: outcome.to_s)

  def page_status_filter_options
    PAGE_STATUS_FILTERS.map { |value| [ t("crawls.page_filters.#{value.presence || "all"}"), value ] }
  end

  def crawl_finished?(crawl) = Crawl::FINISHED_STATUSES.include?(crawl.status)

  def crawl_percent(crawl)
    return 100 if crawl_finished?(crawl)

    done = crawl.pages_crawled + crawl.pages_failed
    target = [ crawl.crawl_config.max_pages, [ crawl.pages_discovered - crawl.pages_skipped, done, 1 ].max ].min
    [ 99, (done * 100.0 / target).round ].min
  end
end
