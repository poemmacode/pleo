module Crawling
  # State transitions of a crawl. Every transition runs under the crawl's row lock.
  module Lifecycle
    MAX_LANES = 4

    module_function

    def start(crawl)
      crawl.with_lock do
        return unless crawl.queued?

        crawl.update!(status: "running", started_at: Time.current,
                      sitemap_status: crawl.crawl_config.use_sitemaps ? "pending" : "skipped")
      end
      Frontier.new(crawl).add([ crawl.crawl_config.start_url ], source: "seed", depth: 0)
      SitemapDiscoveryJob.perform_later(crawl.id) if crawl.crawl_config.use_sitemaps
      dispatch(crawl)
    end

    # Lanes are self-re-enqueuing jobs; extra lanes are harmless because the host rate limit,
    # not the number of lanes, sets the request rate.
    def dispatch(crawl)
      lanes = crawl.current_rps.ceil.clamp(1, MAX_LANES)
      lanes.times { FetchLaneJob.perform_later(crawl.id) }
    end

    def pause(crawl)
      transition(crawl, from: %w[queued running], to: "paused", reason: "user")
    end

    def resume(crawl)
      return false unless transition(crawl, from: %w[paused], to: "running", reason: nil)

      Frontier.new(crawl).recover_stale_claims
      dispatch(crawl)
      true
    end

    def cancel(crawl)
      return false unless transition(crawl, from: %w[queued running paused], to: "cancelled", reason: "user", finished: true)

      Frontier.new(crawl).skip_remaining("cancelled")
      true
    end

    # Called by a lane that found nothing to claim. Completes the crawl once nothing is queued,
    # nothing is in flight and sitemap discovery is over.
    def maybe_finish(crawl)
      frontier = Frontier.new(crawl)
      crawl.with_lock do
        return unless crawl.running?
        return if crawl.sitemap_status == "pending"

        if frontier.recover_stale_claims.positive?
          dispatch(crawl)
          return
        end
        return if frontier.fetching?
        return if frontier.pending? && !frontier.budget_exhausted?

        frontier.skip_remaining("limit")
        sync_page_discovery_fields(crawl)
        crawl.update!(status: "completed", status_reason: completion_reason(crawl), finished_at: Time.current)
      end
    end

    # Sitemaps and later links can lower a URL's depth or mark it in_sitemap after its page was stored.
    def sync_page_discovery_fields(crawl)
      Page.connection.exec_update(<<~SQL.squish, "Sync page discovery fields", [ crawl.id ])
        UPDATE pages SET depth = crawl_urls.depth, in_sitemap = crawl_urls.in_sitemap
        FROM crawl_urls
        WHERE pages.crawl_url_id = crawl_urls.id AND pages.crawl_id = $1
          AND (pages.depth IS DISTINCT FROM crawl_urls.depth OR pages.in_sitemap <> crawl_urls.in_sitemap)
      SQL
    end

    def completion_reason(crawl)
      start_host = URI.parse(crawl.crawl_config.start_url).host
      robots = CrawlHost.find_by(crawl:, host: start_host)
      return "robots_unreachable" if robots&.robots_outcome == "unreachable" && crawl.pages_crawled.zero?

      Frontier.new(crawl).budget_exhausted? ? "max_pages_reached" : nil
    end

    def transition(crawl, from:, to:, reason:, finished: false)
      crawl.with_lock do
        return false unless from.include?(crawl.status)

        crawl.update!(status: to, status_reason: reason, finished_at: finished ? Time.current : crawl.finished_at)
      end
      true
    end
  end
end
