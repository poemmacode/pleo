module Performance
  # Measures a crawl's sample with PSI: a few threads, one request per second to the API, and a daily
  # cap shared by all crawls. Failures are stored per page and never fail the audit.
  module Measure
    COLUMNS = (Parser::LAB_AUDITS.keys + Parser::FIELD_METRICS.keys +
               %i[performance_score opportunities field_scope field_category page_id error]).freeze
    THREADS = 4
    RPS = 1.0
    API_HOST = "www.googleapis.com".freeze

    module_function

    # Returns the status stored on the crawl: nil (disabled), "skipped_no_key", "done" or "limited".
    def call(crawl, limiter: Crawling.rate_limiter)
      config = crawl.crawl_config
      return crawl.update!(performance_status: nil) unless config.run_pagespeed

      client = Performance.client
      return crawl.update!(performance_status: "skipped_no_key") unless client

      crawl.performance_results.delete_all
      pages = Sampler.pick(crawl, size: config.pagespeed_sample)
      allowed = reserve_daily(pages.size)
      queue = Queue.new
      pages.first(allowed).each { queue << _1 }
      results = Queue.new

      Array.new([ THREADS, queue.size ].min) do
        Thread.new do
          while (page = queue.pop(true) rescue nil)
            results << measure(client, page, limiter)
          end
        end
      end.each(&:join)

      # insert_all needs identical keys in every row, failed measurements included.
      rows = Array.new(results.size) { results.pop }.map do |result|
        COLUMNS.index_with { nil }.merge(opportunities: []).merge(result)
          .merge(crawl_id: crawl.id, strategy: "mobile", fetched_at: Time.current)
      end
      PerformanceResult.insert_all(rows) if rows.any?
      crawl.update!(performance_status: allowed < pages.size ? "limited" : "done")
    end

    def measure(client, page, limiter)
      limiter.acquire(API_HOST, rps: RPS, max_wait: 300)
      Parser.parse(client.run(page.url)).merge(page_id: page.id, error: nil)
    rescue Client::Error, SafeHttp::Errors::Base => e
      { page_id: page.id, error: e.message.first(300), opportunities: [] }
    end

    # Atomically takes up to `wanted` requests from today's budget; returns how many were granted.
    def reserve_daily(wanted)
      key = "seo:psi:#{Date.current.iso8601}"
      used = SafeHttp.redis.call("INCRBY", key, wanted)
      SafeHttp.redis.call("EXPIRE", key, 2.days.to_i)
      over = used - Performance.daily_limit
      return wanted if over <= 0

      granted = [ wanted - over, 0 ].max
      SafeHttp.redis.call("DECRBY", key, wanted - granted)
      granted
    end
  end
end
