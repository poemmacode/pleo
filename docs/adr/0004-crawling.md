# ADR 0004 — Crawling engine (Epic B)

Date: 2026-10-17 · Status: accepted

## Decisions

1. **Lanes instead of one job per URL.** `Crawling::FetchLaneJob` claims the next URL from `crawl_urls` (`FOR UPDATE SKIP LOCKED`, BFS order by `depth`), processes it and re-enqueues itself. The lane re-enqueues immediately, not with `wait`: a scheduled job does not start until Sidekiq's next poll (about 5 s), which dropped a 0.5 req/s crawl to about 0.19 req/s in practice. It is only scheduled when the limiter asks to wait more than 2 s (fixed on 2026-10-17). Pausing or cancelling stops new requests at once (the lane checks the state when it starts) and there are no thousands of jobs to purge. The number of lanes (1–4) only provides parallelism; the speed is set by `HostRateLimiter`, so extra lanes have no effect.
2. **Atomic budget.** `pages_claimed` is incremented with an `UPDATE … WHERE pages_claimed < max_pages`, and given back when a URL is skipped or re-queued. `max_pages` is therefore never exceeded, even with concurrent lanes.
3. **Redirects are not followed within a request.** Each URL is requested with `follow_redirects: false`. A 3xx is stored as a page (`redirect_url`) and the target enters the frontier (`source = redirect`). Chains and loops are rebuilt in Epic C from the graph; that is why the `redirect_chain` column proposed in the design does not exist.
4. **robots.txt per host** (`crawl_hosts`), downloaded the first time it is needed. The `domain` scope can span several subdomains, each with its own robots.txt. If it is unreachable (5xx, 429, error) that host is not crawled (RFC 9309). If it is the start host, the crawl ends with `robots_unreachable`.
5. **`domain` scope = the verified host and the hosts under it.** Verifying `www.example.com` does not authorise `blog.example.com`.
6. **Sitemaps** in a separate job, in parallel with the crawl: those in robots.txt plus `/sitemap.xml`, indexes up to 3 levels, at most 200 files and 50 MB decompressed per file. They are streamed with `Nokogiri::XML::Reader` (`NONET`, no external entities). Only sitemaps hosted on hosts of the verified domain are downloaded. Sitemap URLs enter with `depth = NULL` (end of the queue) and, if they later turn up as links, keep the lower depth. When the crawl ends, `depth` and `in_sitemap` are synced into `pages`.
7. **Discovery limit**: at most `10 × max_pages` URLs in the frontier.
8. **Stored HTML**, gzip-compressed in `page_bodies` (`store_html` option, on by default), so Epic C's checks can be re-run without downloading again. A retention policy is still pending.
9. **Retries**: 429/503 (honouring `Retry-After` via `penalize`) and connection errors, up to 3 attempts. Timeouts are recorded straight away as a failure (`fetch_error`).
10. **Adaptive rate**: `SafeHttp::AdaptiveRate` is persisted in `crawls.adaptive_rate` under `with_lock`. On `:pause`, the crawl becomes `paused` with `status_reason = server_overloaded`.

## Later change (2026-10-20)

Limits for **unverified** domains raised from 200 pages at 0.5 req/s to **2,000 pages and 2 req/s**, with defaults of 500 pages at 1 req/s. The terms confirmation stays. Reason: with 200 pages it was impossible to run useful audits of one's own sites without verifying them first. 2 req/s is still a low load for any server, and `robots.txt`, `Crawl-delay` and the adaptive rate still apply.

## Limitations

- The integration test runs jobs inline (`perform_enqueued_jobs`), so it does not exercise real concurrency. Concurrency was tested by hand with Sidekiq against books.toscrape.com: 20 pages at 0.5 req/s, minimum measured gap 1.9 s.
- Claims abandoned by a dead worker are recovered after 2 minutes, but only when another lane reaches `maybe_finish` or the crawl is resumed. A periodic watchdog for crawls with no live lane is missing (sidekiq-cron, Epic K).
