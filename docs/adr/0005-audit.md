# ADR 0005 — Extraction and audit (Epic C)

Date: 2026-10-17 · Status: accepted

## Decisions

1. **Extraction happens at fetch time** (`Crawling::PageExtractor`, `StructuredDataExtractor`) and is stored in `pages` columns, so the audit never re-parses HTML. `bin/rails audit:reextract CRAWL_ID=…` repeats the extraction from `page_bodies` when the extractor improves.
2. **The audit starts when the crawl completes** (`Audit::RunAuditJob`, `audit` queue) and can be re-run with `POST /crawls/:id/audit`. Steps: link graph → external links → PageRank → site facts → checks. Re-running replaces the previous issues.
3. **Checks as classes with a DSL** (`define key:, category:, severity:, weight:`). `Audit::Catalog` is the ordered list and syncs `check_definitions` on every audit. The titles, descriptions and fixes were written from scratch; originally in Spanish inside the DSL, they now live in `config/locales/checks.{en,es}.yml` ([ADR 0010](0010-internationalization.md)).
4. **Link checks run in SQL** (`LinkQueryCheck`), grouped by source page, so millions of links are never loaded into Ruby. Per-page checks use a `Context` with a single column query.
5. **Redirect chains and loops** are rebuilt by following `redirect_url` between crawled pages (see ADR 0004).
6. **Internal PageRank**: followed links (no nofollow) between HTML 200 pages, damping 0.85 and 20 iterations; the rank of dangling pages is spread across all pages. Edges are read as two Postgres arrays. With 50,000 nodes and 1 M edges it takes about 6 s in Ruby.
7. **Near duplicates** with 64-bit SimHash over word 3-shingles and Hamming distance ≤ 3. They are found with 4 bands of 16 bits (by the pigeonhole principle, two hashes at distance ≤ 3 match in at least one band), so not every pair has to be compared.
8. **Structured data**: JSON-LD (including `@graph`), Microdata and RDFa Lite. Validated against a snapshot of the schema.org vocabulary (`config/schema_org/vocabulary.json`, CC BY-SA, regenerated with `bin/rails schema_org:refresh`) and against our own rules for required and recommended properties for 18 types, with type inheritance.
9. **External links**: HEAD and, if refused (403/405/501), GET with `Range`. One request per second per host, respecting robots.txt, at most 1,000 URLs per crawl and 6 threads. 429s and robots blocks do not count as broken links.
10. **Site facts for GEO**: AI crawlers blocked in robots.txt (list in `Audit::SiteFacts::AI_BOTS`) and presence of `/llms.txt`.

## Changes from the catalogue in docs/03 §5

- `perf.slow_ttfb` becomes `perf.slow_response`: the crawler measures the total HTML download time, not the TTFB.
- `perf.lcp_poor`, `perf.cls_poor`, `perf.inp_poor` and `perf.score_low` arrive with PageSpeed Insights (Epic E).
- `ai.content_requires_js` arrives with JS rendering (iteration 1.1).
- `http.timeout` also covers connection errors (any fetch without a response that is not a TLS error).

## Known limitations

- The text used for word count and SimHash only strips `nav`, `header`, `footer`, scripts and the like; it does not detect generic templates. On sites with large sidebars and little unique content it can flag pages as near duplicates when they are not — for example, two books.toscrape.com categories that share a 50-category sidebar.
- schema.org validation does not check value ranges (expected types per property) or enumerations.
- The robots.txt check for external links is cached in memory for one audit only.
