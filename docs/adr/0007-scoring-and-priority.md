# ADR 0007 — Health score and issue priority (Epic D)

Date: 2026-10-20 · Status: accepted · Adjusts the formulas in docs/03 §6

## Decisions

Implemented in `Audit::Scoring`, which runs at the end of every audit.

1. **Check coverage**: the share of crawled pages (any status) with the finding, capped at 1. Site-wide checks (`site_wide!`: no sitemap, AI bots blocked, no llms.txt) always count as 1.
2. **Penalty**: `weight × severity factor × √coverage`. The square root keeps a problem on 1 % of pages from being irrelevant and one on 100 % from weighing linearly.
3. **Category score**: `100 × (1 − Σ penalty / Σ weight × factor)` over every check in the category.
4. **Overall health**: weighted mean of the categories: crawlability 22, indexability 18, links 14, metadata 14, content 10, HTTPS 6, structured data 5, mobile 5, performance 3 and AI search 3 (total 100). A site with no findings scores 100; every check failing on every page scores 0.
5. **Notices at 25 %**. Findings with *notice* severity count with a quarter of their weight everywhere. *Change from docs/03*: there, notices subtracted "at most 5 global points", but the performance category only has notices until PageSpeed arrives (Epic E) and with that rule it would have no score. A single factor is simpler and consistent.
6. **Priority of each finding** (0–100): `10 × weight × factor × (0.5 × coverage + 0.5 × importance)`.
   - Importance is internal PageRank relative to the crawl's maximum.
   - For pages outside the graph (errors, redirects), inbound links relative to the maximum are used.
   - Findings without a page count as importance 1.
   - A check's priority is the mean of its findings. The report sorts checks by it and, within each check, pages from most to least important (paginated by page number).
7. **Comparison**: the crawl page shows the difference from the previous scored crawl of the same domain.

## Pending

- Once Search Console is available, importance will combine PageRank and impressions (docs/03 §6).
- The weights are a starting point and should be calibrated with real audits.
