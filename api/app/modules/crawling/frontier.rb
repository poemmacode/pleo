module Crawling
  # The crawl's URL queue (crawl_urls), ordered breadth-first by depth.
  # Claiming uses FOR UPDATE SKIP LOCKED so concurrent lanes never take the same URL, and the page
  # budget (max_pages) is consumed with a conditional UPDATE so it can never be exceeded.
  class Frontier
    BATCH_SIZE = 1_000
    STALE_CLAIM = 2.minutes
    MAX_ATTEMPTS = 3

    def initialize(crawl)
      @crawl = crawl
    end

    # Adds normalized URLs that are in scope and pass include/exclude patterns. Known URLs get the
    # smaller depth and the in_sitemap flag merged in. Returns the number of new URLs.
    def add(urls, source:, depth:, in_sitemap: false)
      urls = urls.uniq.select { |url| @crawl.crawl_scope.include?(url) && @crawl.crawl_config.path_allowed?(url) }
      room = @crawl.discovery_cap - Crawl.where(id: @crawl.id).pick(:pages_discovered)
      return 0 if urls.empty? || room <= 0

      inserted = urls.first(room).each_slice(BATCH_SIZE).sum do |batch|
        rows = batch.map do |url|
          { crawl_id: @crawl.id, url:, url_hash: CrawlUrl.hash_url(url), depth:, source:, in_sitemap: }
        end
        result = CrawlUrl.upsert_all(
          rows,
          unique_by: %i[crawl_id url_hash],
          on_duplicate: Arel.sql(<<~SQL.squish),
            depth = LEAST(crawl_urls.depth, EXCLUDED.depth),
            in_sitemap = crawl_urls.in_sitemap OR EXCLUDED.in_sitemap
          SQL
          returning: Arel.sql("(xmax = 0) AS inserted")
        )
        result.rows.count { |(new_row)| new_row }
      end
      @crawl.increment!(pages_discovered: inserted) if inserted.positive?
      inserted
    end

    # Returns the next URL to fetch, or nil when nothing is pending or the page budget is spent.
    def claim
      return unless take_budget

      sql = <<~SQL.squish
        UPDATE crawl_urls SET state = 'fetching', attempts = attempts + 1, claimed_at = NOW()
        WHERE id = (
          SELECT id FROM crawl_urls
          WHERE crawl_id = $1 AND state = 'pending'
          ORDER BY depth ASC NULLS LAST, id ASC
          LIMIT 1 FOR UPDATE SKIP LOCKED
        )
        RETURNING *
      SQL
      row = CrawlUrl.connection.exec_query(sql, "Frontier claim", [ @crawl.id ]).first
      row ? CrawlUrl.instantiate(row) : (release_budget && nil)
    end

    def release_budget
      Crawl.where(id: @crawl.id).where("pages_claimed > 0").update_all("pages_claimed = pages_claimed - 1")
    end

    def requeue(crawl_url)
      crawl_url.update!(state: "pending", claimed_at: nil)
      release_budget
    end

    def complete(crawl_url)
      crawl_url.update!(state: "done")
    end

    def skip(crawl_url, reason, release: true)
      crawl_url.update!(state: "skipped", skip_reason: reason)
      @crawl.increment!(pages_skipped: 1)
      release_budget if release
    end

    def budget_exhausted?
      Crawl.where(id: @crawl.id).pick(:pages_claimed) >= @crawl.crawl_config.max_pages
    end

    def pending? = scope.where(state: "pending").exists?

    def fetching? = scope.where(state: "fetching").exists?

    # Returns claims abandoned by crashed workers to the queue (or gives up after MAX_ATTEMPTS).
    def recover_stale_claims
      stale = scope.where(state: "fetching").where(claimed_at: ...STALE_CLAIM.ago)
      retried = stale.where(attempts: ...MAX_ATTEMPTS).update_all(state: "pending", claimed_at: nil)
      failed = stale.update_all(state: "skipped", skip_reason: "error")
      @crawl.increment!(pages_skipped: failed) if failed.positive?
      (retried + failed).times { release_budget }
      retried
    end

    # When the budget is spent, whatever is still queued will never be fetched.
    def skip_remaining(reason)
      count = scope.where(state: "pending").update_all(state: "skipped", skip_reason: reason)
      @crawl.increment!(pages_skipped: count) if count.positive?
      count
    end

    private
      def scope = CrawlUrl.where(crawl_id: @crawl.id)

      def take_budget
        Crawl.where(id: @crawl.id).where("pages_claimed < ?", @crawl.crawl_config.max_pages)
          .update_all("pages_claimed = pages_claimed + 1") == 1
      end
  end
end
