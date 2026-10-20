# ADR 0008 — Performance with PageSpeed Insights (Epic E)

Date: 2026-10-20 · Status: accepted

## Decisions

1. **A single source: PSI v5.** Its response includes the Lighthouse lab run and CrUX field data (`loadingExperience`, 28-day p75), so there is no need to call the CrUX API separately. Field data can be for the page or for the origin (`origin_fallback`); origin data is shown as "whole site" and not used in the checks.
2. **An API key is required** (`PAGESPEED_API_KEY`). The anonymous quota is shared and in the 2026-10-20 test it returned 429 ("Queries per day"). Without a key, the audit sets `performance_status = skipped_no_key` and the interface explains it.
3. **A sample, not the whole site.** `Performance::Sampler` picks, in this order, the home page, one page per URL template (the one with the highest PageRank), and then the highest-PageRank pages, up to `pagespeed_sample` (10 by default, 30 at most). A template groups URLs whose numbers and last segment differ (`/blog/:n/*`). Only indexable HTML 200 pages count.
4. **Inside the audit**, after PageRank and before the checks. 4 measurements run at a time, 1 request per second to `www.googleapis.com` (with `HostRateLimiter`), and there is a global daily cap in Redis (`PAGESPEED_DAILY_LIMIT`, 500 by default). If the cap cuts the sample short, `performance_status = limited`. Errors for one page are stored in its result and do not break the audit.
5. **The key never appears in errors or logs**: the client only passes on PSI's message, not the request URL.
6. **Checks** (on the measured pages):
   - `perf.lcp_poor`: LCP > 4 s.
   - `perf.cls_poor`: CLS > 0.25.
   - `perf.inp_poor`: INP > 500 ms; only with the page's field data, because lab INP does not exist.
   - `perf.score_low`: score < 50.
   LCP and CLS use the page's field value if there is one and the lab value otherwise; the finding says which one was used. In the health score these checks are `sampled!`: their coverage is affected / measured, not affected / crawled.
7. **Opportunities**: the top 5 by savings of 100 ms or more are stored. Both `details.overallSavingsMs` (Lighthouse ≤ 11) and `metricSavings` (Lighthouse 12+, max of LCP/FCP) are supported.

## Limitations

- The parser was written from PSI v5's documented structure and tested with synthetic responses. It still has to be checked against a real response once there is a key.
- Only the mobile strategy is measured; the `strategy` column allows adding desktop.
