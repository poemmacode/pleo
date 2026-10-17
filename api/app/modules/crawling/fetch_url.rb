module Crawling
  # Fetches one claimed URL and records the outcome (docs/03 §2). Returns:
  #   :done            page stored or URL skipped
  #   [:wait, seconds] the host's rate slot is not free yet; the URL went back to the queue
  class FetchUrl
    RETRYABLE_STATUSES = [ 429, 503 ].freeze
    DEFAULT_BACKOFF = 30
    MAX_INLINE_WAIT = 2.0
    HTML_TYPES = %r{\A(text/html|application/xhtml\+xml)}i

    def initialize(crawl, crawl_url, frontier: Frontier.new(crawl), limiter: Crawling.rate_limiter)
      @crawl = crawl
      @crawl_url = crawl_url
      @frontier = frontier
      @limiter = limiter
      @config = crawl.crawl_config
      @host = URI.parse(crawl_url.url).host
    end

    def call
      crawl_host = HostRegistry.fetch(@crawl, @crawl_url.url)
      return skip("robots") unless crawl_host.robots_policy.allowed?(@crawl_url.url)

      wait = reserve_slot(crawl_host)
      if wait
        @frontier.requeue(@crawl_url)
        return [ :wait, wait ]
      end

      response = Crawling.http_client(@crawl).get(@crawl_url.url, follow_redirects: false)
      return retry_later(response) if RETRYABLE_STATUSES.include?(response.status) && @crawl_url.attempts < Frontier::MAX_ATTEMPTS

      store(response)
      :done
    rescue SafeHttp::Errors::UnsafeTarget, SafeHttp::Errors::InvalidUrl
      skip("unsafe_host")
    rescue SafeHttp::Errors::Base => e
      adapt(:error)
      if @crawl_url.attempts < Frontier::MAX_ATTEMPTS && e.is_a?(SafeHttp::Errors::Connection)
        @frontier.requeue(@crawl_url)
      else
        store_failure(e)
      end
      :done
    end

    private
      # Waits briefly in-process; longer waits go back through the job queue.
      def reserve_slot(crawl_host)
        rps = [ @crawl.current_rps, crawl_host.crawl_delay ? 1.0 / crawl_host.crawl_delay : Float::INFINITY ].min
        rps = rps.clamp(SafeHttp::AdaptiveRate::MIN_RPS, SafeHttp::HostRateLimiter::MAX_RPS)
        wait = @limiter.reserve(@host, rps:)
        return if wait.zero?
        return wait if wait > MAX_INLINE_WAIT

        sleep(wait)
        reserve_slot(crawl_host)
      end

      def skip(reason)
        @frontier.skip(@crawl_url, reason)
        :done
      end

      def retry_later(response)
        adapt(response.status)
        delay = SafeHttp::RetryAfter.parse(response.header("retry-after")) || DEFAULT_BACKOFF
        @limiter.penalize(@host, delay)
        @frontier.requeue(@crawl_url)
        :done
      end

      def store(response)
        adapt(response.status)
        content_type = response.header("content-type")
        page = Page.create!(
          crawl: @crawl, crawl_url: @crawl_url, url: @crawl_url.url, depth: @crawl_url.depth,
          in_sitemap: @crawl_url.in_sitemap, status_code: response.status, content_type:,
          content_length: response.body.bytesize, truncated: response.truncated, response_ms: response.elapsed_ms,
          ip: response.ip, headers: response.headers.slice(*KEPT_HEADERS), fetched_at: Time.current,
          redirect_url: redirect_target(response)
        )
        html = response.status == 200 && content_type.to_s.match?(HTML_TYPES)
        PageBody.create!(page:, body_gzip: ActiveSupport::Gzip.compress(response.body)) if html && @config.store_html
        if html
          PageAnalysis.apply(page, response.body, response.headers)
        else
          page.update!(indexable: false, indexability_reason: PageAnalysis.unanalysable_reason(page))
        end
        @frontier.add([ page.redirect_url ], source: "redirect", depth: @crawl_url.depth) if page.redirect_url
        discover_links(page, response.body) if html
        @frontier.complete(@crawl_url)
        @crawl.increment!(pages_crawled: 1)
      end

      KEPT_HEADERS = %w[content-type content-length cache-control last-modified etag x-robots-tag link
                        location content-encoding strict-transport-security server vary].freeze

      def redirect_target(response)
        return unless response.redirect? && response.header("location")

        UrlNormalizer.resolve(@crawl_url.url, response.header("location"))
      end

      def store_failure(error)
        Page.create!(crawl: @crawl, crawl_url: @crawl_url, url: @crawl_url.url, depth: @crawl_url.depth,
                     in_sitemap: @crawl_url.in_sitemap, fetch_error: "#{error.class.name.demodulize}: #{error.message}".first(255),
                     fetched_at: Time.current, indexable: false, indexability_reason: "fetch_error")
        @frontier.complete(@crawl_url)
        @crawl.increment!(pages_failed: 1)
      end

      def discover_links(page, html)
        result = LinkExtractor.extract(html, page.url)
        rows = result.links.map do |link|
          { crawl_id: @crawl.id, from_page_id: page.id, to_url: link.url, to_url_hash: CrawlUrl.hash_url(link.url),
            internal: @crawl.crawl_scope.include?(link.url), anchor: link.anchor, rel: link.rel }
        end
        Link.insert_all(rows) if rows.any?

        next_depth = page.depth.to_i + 1
        return if next_depth > @config.max_depth
        return if @config.respect_nofollow && result.meta_nofollow

        followable = result.links.reject { |link| @config.respect_nofollow && link.rel.include?("nofollow") }
        @frontier.add(followable.map(&:url), source: "link", depth: next_depth)
      end

      # Feeds the crawl's adaptive rate; halves the speed or pauses the crawl when the site struggles.
      def adapt(outcome)
        @crawl.with_lock do
          state, decision = @crawl.adaptive.record(outcome)
          attrs = { adaptive_rate: state.to_h, current_rps: state.rps }
          attrs.merge!(status: "paused", status_reason: "server_overloaded") if decision == :pause && @crawl.running?
          @crawl.update!(attrs)
        end
      end
  end
end
