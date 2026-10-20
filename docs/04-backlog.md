# Backlog

Format: **ID · story** — acceptance criteria (AC). Estimates in person-days (d). Each epic is a *vertical slice* that ends with controller + UI + green tests.

## MVP

### Epic 0 — Skeleton (≈5 d) — ✅ done

- **0.1 · Initial repository** — AC: Rails 8 application (Postgres, RSpec; Hotwire since ADR 0006) starts with one command (`bin/dev`); `docker compose up` starts Postgres and Redis; README with setup.
- **0.2 · CI** — AC: GitHub Actions runs RSpec (system specs included), rubocop, brakeman, bundler-audit and importmap audit; fails if any of them fails.
- **0.3 · Authentication** — AC: sign-up disabled by default (user created with `bin/rails users:create`); sign in/out with an `HttpOnly; Secure; SameSite=Lax` session cookie; CSRF protection; unauthenticated requests are redirected to sign in.
- **0.4 · Projects and domains** — AC: project CRUD; adding a domain normalises the host (punycode, lowercase, optional `www.` removal) and rejects IPs and blocked hosts.
- **0.5 · Domain verification** — *DNS TXT in Epic 0; file and meta tag added in Epic A (they need SafeHttp).* AC: DNS TXT (`seo-platform-verify=<token>`), file `/.well-known/seo-platform-<token>.txt` and meta tag methods; verification goes through SafeHttp/DNS; one unique token per domain; success sets `verified_at`; failure returns 422 with a reason.

### Epic A — SafeHttp and robots (≈6 d) — ✅ done (see [ADR 0003](adr/0003-safehttp.md))

- **A.1 · Safe HTTP client** — AC: every case in the SSRF table of [03 §3.3](03-mvp-crawler.md) is rejected with `UnsafeTargetError`; the connection uses the validated IP (spec with a rebinding stub resolver); TLS verifies the hostname; size/time/redirect limits applied; 100 % branch coverage in the module.
- **A.2 · robots.txt parser (RFC 9309)** — AC: passes the RFC's set of cases (groups by UA, longest match, `*`, `$`, tied `Allow` vs `Disallow` → allow); 5xx/timeout ⇒ disallow all; 4xx ⇒ allow all; extracts `Sitemap:` and `Crawl-delay`.
- **A.3 · Per-host rate limiting** — AC: token bucket in Redis; with `rps=2` and 10 workers, an integration test measures ≤ 2 req/s ±10 % to the fixture host; `Retry-After` honoured.
- **A.4 · Self-protection against overload** — *Policy implemented (`SafeHttp::AdaptiveRate`); wired to the crawl state in B.1.* AC: if >20 % of responses in 60 s are 429/5xx, rps is halved; after 3 reductions the crawl becomes `paused` with a visible reason.

### Epic B — Crawling (≈8 d) — ✅ done (see [ADR 0004](adr/0004-crawling.md))

- **B.1 · Create/control a crawl** — AC: creating a crawl validates the config against the limits (verified/unverified); pause/resume/cancel change the state and stop new requests within < 5 s.
- **B.2 · Sitemap discovery** — AC: finds sitemaps in robots.txt and `/sitemap.xml`; supports nested indexes (max. depth 3), `.gz`, and >50k URLs through paginated indexes; out-of-scope URLs are ignored and counted.
- **B.3 · Link discovery** — AC: BFS respecting `max_depth`, include/exclude, scope and robots; no duplicates (unique constraint `crawl_id,url_hash`); normalisation as in 03 §2.
- **B.4 · Fetch and storage** — AC: each URL produces exactly one `pages` row or a `skip_reason`; redirects stored as 3xx pages with `redirect_url` (chains rebuilt in C); the crawl ends (`completed`) when nothing is pending or `max_pages` is reached, and never exceeds `max_pages`.
- **B.5 · Progress** — AC: the crawl page shows discovered/crawled/failed with ≤ 5 s delay.

### Epic C — Extraction and checks (≈10 d) — ✅ done (see [ADR 0005](adr/0005-audit.md))

- **C.1 · On-page extraction** — AC: with a set of ≥20 HTML fixtures (including malformed HTML, `<base>`, multiple titles, canonical in the header and in the head), the fields in 03 §4 match the expected values.
- **C.2 · Links and statuses** — AC: each internal link resolves `to_page_id` and `status_code`; external links are checked with HEAD (falling back to a ranged GET), limited to 1 req/s per external host and max. 1,000 per crawl.
- **C.3 · Structured data** — AC: extracts JSON-LD, Microdata and RDFa; detects invalid JSON; validates `@type` against a versioned snapshot of the schema.org vocabulary (downloaded from schema.org, CC BY-SA licence) and required properties for ≥8 types.
- **C.4 · Duplicates** — AC: duplicate titles and descriptions are grouped by exact hash (normalised: trim, whitespace, lowercase); near-duplicate content by simhash (Hamming ≤ 3); only indexable 200 pages count.
- **C.5 · Check catalogue** — AC: every check in 03 §5 implemented with its own spec (positive and negative fixture); `check_definitions` seeded. *Texts originally in Spanish; since ADR 0010 they live in `config/locales/checks.{en,es}.yml`.*
- **C.6 · Site-wide checks** — AC: orphans, depth, internal PageRank (20 iterations, damping 0.85) computed in `FinalizeCrawlJob` in < 60 s for 50k pages on the development machine.

### Epic D — Score and prioritisation (≈3 d) — ✅ done (see [ADR 0007](adr/0007-scoring-and-priority.md))

- **D.1 · Health score** — AC: formula from 03 §6 implemented; tests with known scenarios (perfect site = 100; every check failing on 100 % of pages = 0); per-category and global score shown in the audit summary.
- **D.2 · Prioritisation** — AC: issues sorted by `priority_score` desc by default; each issue includes `how_to_fix`.

### Epic E — Performance (≈3 d) — ✅ done (see [ADR 0008](adr/0008-pagespeed.md))

- **E.1 · PSI** — AC: with an API key configured, measures the sample defined in 03 §7; stores lab metrics and field metrics when present; PSI errors (e.g. a non-public URL) are recorded without failing the crawl; a configurable daily cap is respected; tests with recorded responses.
- **E.2 · Performance and mobile checks** — AC: `perf.*` and `mobile.viewport_missing` generated from E.1/C.1.

### Epic F — Reports (≈4 d) — ✅ done (see [ADR 0009](adr/0009-reports.md))

- **F.1 · CSV/XLSX** — AC: the exports in 03 §8 are generated in < 60 s for 10k pages; documented columns; UTF-8 characters correct in Excel (BOM in CSV).
- **F.2 · PDF** — AC: executive summary with score, categories, top-10 prioritised issues and recommendations; generated without external network dependencies.
- **F.3 · Secure download** — AC: short-lived download; only the project owner can request it.

### Epic G — MVP UI (≈8 d, in parallel with B–F) — Hotwire (ADR 0006); G.1, G.2, G.3, G.5, G.6 done

- **G.1** Crawl form with validations and an explanation of the limits. AC: does not allow out-of-range values; shows the terms notice for unverified domains.
- **G.2** Live progress. AC: progress bar and counters update without reloading.
- **G.3** Audit summary. AC: global score, per category, top issues; navigation to affected pages.
- **G.4** Page explorer. AC: keyset-paginated table ("Load more" with Turbo Stream, without loading 50k rows at once), filters by status, indexability, depth, URL text. *Done: status filter.*
- **G.5** Page detail. AC: metadata, heading tree, in/out links, schema, issues, performance.
- **G.6** Exports. AC: start and download reports.
- **G.7** Basic accessibility. AC: keyboard navigation, AA contrast, no serious `axe` violations in the system specs.
- **G.8** Internationalisation. AC: English by default, Spanish available; the language picked in the top bar is saved on the user; reports use the requester's language (ADR 0010). ✅

### Definition of done (MVP)

1. A crawl of a real verified site of ~1,000 pages finishes without errors, respecting robots.txt and the configured rps.
2. The crawl of the fixture site produces exactly the expected set of issues ("golden" integration test).
3. SSRF security suite green.
4. CSV/XLSX/PDF export downloadable.
5. README covering setup, deployment and limitations.

**Total MVP estimate: ≈ 47 person-days** (≈ 9–10 weeks full time; double that part time).

## Post-MVP (epic summary)

| Epic | Key stories | Notable AC |
|---|---|---|
| H. JS rendering (1.1) | Renderer service + Smokescreen; compare raw vs rendered HTML | SSRF tests repeated against the renderer; `ai.content_requires_js` |
| I. Search Console | OAuth, incremental daily sync, performance, striking distance, URL Inspection (quota 2,000/day/property) | Encrypted tokens; idempotent re-sync; issue prioritisation uses impressions |
| J. GA4 | Traffic by landing page, AI referrers | List of AI referrers kept in config |
| K. Recrawls and diff | Scheduling, crawl comparison, email alerts | Correct diff with A/B fixtures |
| L. Keywords | Configurable provider, 30-day cache, lists, clusters, own KD | Source and date visible; budget respected |
| M. Rank tracking | GSC + SERP API, visibility, alerts | Configurable frequency; series kept separate by source |
| N. Competitors / Keyword gap | Discovery, 5-domain gap | Category rules tested |
| O. On-page | URL+keyword recommendations vs top 10 | Each recommendation with evidence |
| P. GEO | Multi-LLM prompts, mentions, citations, sentiment | Hard budget cut-off; auditable answers |
| Q. Backlinks | GSC CSV import, BWT API, Common Crawl authority, optional provider | Idempotent import; metric labelled as an estimate |
