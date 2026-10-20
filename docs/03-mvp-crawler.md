# Phase 3 — MVP plan: technical SEO crawler

The MVP is **only** the technical audit module (plus the base: projects, domains, auth). It does not depend on any paid API. The only external API is PageSpeed Insights (free with an API key).

## 1. MVP scope

Included:
1. URL discovery from sitemaps (robots.txt, `/sitemap.xml`, indexes, `.gz`) and internal links.
2. Configurable limits: pages, depth, req/s, include/exclude, maximum response size.
3. HTTP status monitoring and redirect chains.
4. Title and meta description analysis.
5. Canonical and robots directives (robots.txt, meta robots, X-Robots-Tag).
6. Heading hierarchy.
7. Internal, external and broken links.
8. Duplicate metadata and content detection.
9. Structured data extraction and validation (JSON-LD, Microdata, RDFa).
10. Performance and mobile with the PageSpeed Insights API (+ CrUX for field data).
11. Health score, prioritisation and exportable reports (CSV, XLSX, PDF).
12. Safety: robots.txt, site terms, crawl budget, SSRF / DNS rebinding protection.

Excluded from the MVP (later phase): JS rendering with Playwright (designed here, built in iteration 1.1), GSC, scheduled recrawls, crawl comparison.

## 2. Crawl flow

The diagram is the original design; the implementation replaced one job per URL with a few "lanes" that each claim URLs from the frontier (ADR 0004), and the JSON API with HTML controllers (ADR 0006).

```mermaid
sequenceDiagram
  participant U as User
  participant API as Rails
  participant Q as Sidekiq
  participant H as SafeHttp
  participant W as Site
  U->>API: POST /crawls (config)
  API->>API: validate config + verified domain + SafeHttp.preflight(start_url)
  API->>Q: StartCrawlJob
  Q->>H: GET /robots.txt
  H->>W: (validated, pinned IP)
  Q->>Q: parse robots, crawl-delay, Sitemap:
  Q->>Q: SitemapDiscoveryJob → crawl_urls(source=sitemap)
  Q->>Q: seed start_url → crawl_urls(source=seed)
  loop while there are pending URLs and max_pages is not reached
    Q->>Q: FetchLaneJob — per-host rate limiter
    Q->>H: GET url (redirects not followed automatically)
    H->>W: request
    W-->>H: response (≤ max_bytes)
    Q->>Q: parse (Nokogiri) → pages, links, structured_data
    Q->>Q: enqueue in-scope internal links (dedupe by url_hash)
  end
  Q->>Q: FinalizeCrawlJob: site-wide checks (duplicates, orphans, broken links, internal PageRank)
  Q->>Q: PSI on a sample of URLs
  Q->>Q: scoring → health_score, priority_score
  API-->>U: GET /crawls/:id (status=completed)
```

### Details

- **URL normalisation**: lowercase scheme and host, drop the default port, drop the fragment, resolve `.`/`..`, sort query params (optional), remove configurable tracking params (`utm_*`, `gclid`, `fbclid`), IDN → punycode. `url_hash = sha256(normalised_url)`.
- **Scope**: `domain` (host and subdomains of the registrable domain — via the Public Suffix List), `subdomain` (exact host), `subfolder` (host + path prefix).
- **Frontier**: `crawl_urls` table with a state; `FinalizeCrawlJob` fires when nothing is left `pending/fetching`.
- **Redirects**: followed manually (max. 10), re-validating each hop with SafeHttp; `redirect_chain` is stored. Out-of-scope targets are recorded but not crawled.
- **Content types**: HTML is parsed; PDFs/images only HEAD/status (for broken links). `max_page_bytes` defaults to 5 MB; reading from the socket stops once it is exceeded.
- **Retries**: 429/503 → honour `Retry-After`, exponential backoff, max. 3. If >20 % of responses are 429/5xx in a 1-minute window, the crawl automatically **halves** its rate; if it keeps happening, it pauses (`status=paused`, reason `server_overloaded`).
- **Timeouts**: connect 5 s, read 15 s, 30 s total per request.

## 3. Crawler safety

### 3.1 Responsible crawling policy

| Rule | Implementation |
|---|---|
| robots.txt | Own parser following **RFC 9309** (grouping by UA, `Allow`/`Disallow` with longest match, `*` and `$`). If robots.txt returns 5xx or times out → nothing is crawled (treated as "disallow all") and this is reported. 4xx → everything is allowed, as the RFC says. robots cache ≤ 24 h. **Cannot be switched off.** |
| Crawl-delay | If present, `effective_rps = min(configured_rps, 1/crawl_delay)`. |
| User-Agent | Identifiable: `SEOPlatformBot/0.1 (+https://<own-domain>/bot; personal use)`. robots.txt is evaluated for the `SEOPlatformBot` token and for `*`. In "mobile" mode the UA adds a mobile token, but the bot token stays. Googlebot is never impersonated. |
| Verified domains | Full crawls only for domains with verified ownership (DNS TXT, HTML file, meta tag or GSC property). Unverified domains (competitors, SERP top 10): max. 2,000 pages, 2 req/s, no JS rendering (previously 200 pages at 0.5 req/s; raised on 2026-10-20 at the user's request, see ADR 0004). |
| Budget | Hard global limits: max. 50,000 pages per crawl, 10 req/s, 2 concurrent crawls per user, 1 active crawl per host. |
| Site terms | Mandatory checkbox when creating a crawl for an unverified domain ("I have checked that the site's terms allow this access"). No rotating proxies, no CAPTCHA solving, no evading blocks: a detected 403/CAPTCHA is recorded as such and the crawl of that host **stops**. |
| `noindex`/`nofollow` | Honoured for the *decision to follow links* only if the user chooses so (by default an auditor does follow internal `nofollow` links in order to detect them; configurable). |

### 3.2 SSRF protection

Every outbound request (crawler, sitemaps, robots, future "test this URL" features) goes through `SafeHttp`. Steps for each request and **for each redirect hop**:

1. **Strict parsing** with `Addressable::URI`: only `http`/`https`; reject userinfo (`user:pass@`), empty hosts, control characters and spaces.
2. **Ports**: only 80 and 443 (list configurable by the admin, never by the end user).
3. **IP literal host**: normalise with `IPAddr` (catches decimal `2130706433`, octal `0177.0.0.1`, hex `0x7f.1`, IPv4-mapped `::ffff:127.0.0.1`, NAT64 `64:ff9b::/96`) and apply the block list.
4. **Own DNS resolution** (`Resolv::DNS`, 3 s timeout), getting **all** A and AAAA records. If **any** of them is on the block list → reject (prevents mixed answers).
5. **Block list** (IPv4/IPv6):
   - `0.0.0.0/8`, `10.0.0.0/8`, `100.64.0.0/10` (CGNAT), `127.0.0.0/8`, `169.254.0.0/16` (includes `169.254.169.254`, AWS/GCP/Azure metadata, and ECS's `169.254.170.2`), `172.16.0.0/12`, `192.0.0.0/24`, `192.0.2.0/24`, `192.88.99.0/24`, `192.168.0.0/16`, `198.18.0.0/15`, `198.51.100.0/24`, `203.0.113.0/24`, `224.0.0.0/4`, `240.0.0.0/4`, `255.255.255.255/32`.
   - `::/128`, `::1/128`, `::ffff:0:0/96` (the embedded IPv4 is re-evaluated), `64:ff9b::/96`, `100::/64`, `2001:db8::/32`, `fc00::/7` (includes `fd00:ec2::254`, EC2's IPv6 metadata), `fe80::/10`, `ff00::/8`.
   - Hostnames: `localhost`, `*.localhost`, `*.local`, `*.internal`, `metadata`, `metadata.google.internal`, `instance-data`, and the deployment's internal service names (`postgres`, `redis`, `renderer`…).
6. **Pin the IP (anti DNS rebinding)**: the TCP connection is opened **to the already validated IP**, not to the hostname; the original `Host:` and the hostname as SNI are sent for TLS, and the certificate is verified against the hostname. A second malicious lookup with TTL 0 therefore has no effect.
7. **No environment proxies** (`HTTP_PROXY` ignored) and redirects are never followed automatically (the redirect step handles them, repeating 1–6).
8. **Limits**: response size, total time, number of redirects, bounded decompression (protection against *zip bombs*: max. ratio 100:1 and an absolute cap).
9. **Logging**: every rejection is stored as `skip_reason=unsafe_host` with the resolved IP, for auditing.

**Defence in depth (infrastructure)**: IMDSv2 required with hop limit 1; worker and renderer security group / NACL that **denies egress** to `10/8`, `172.16/12`, `192.168/16`, `169.254/16` and the data subnet; the renderer reaches the internet only through **Smokescreen**, which applies the same policy on CONNECT (resolving and validating the IP at connect time).

**Renderer (Playwright, iteration 1.1)**: container without AWS credentials, no access to Postgres/Redis, Chromium with `--proxy-server=smokescreen`, a `page.route('**/*')` that aborts non-http(s) schemes and top-level `file:`/`data:`, timeouts, one context per page, no downloads, and WebSockets/WebRTC blocked (`--force-webrtc-ip-handling-policy=disable_non_proxied_udp`).

### 3.3 Mandatory security tests (RSpec)

Cases that must be **rejected**: `http://127.0.0.1`, `http://2130706433`, `http://0177.0.0.1`, `http://0x7f.0.0.1`, `http://[::1]`, `http://[::ffff:127.0.0.1]`, `http://169.254.169.254/latest/meta-data/`, `http://[fd00:ec2::254]`, `http://metadata.google.internal`, `http://localhost.`, `http://foo.localhost`, `http://user:pass@example.com`, `gopher://`, `file:///etc/passwd`, `http://example.com:6379`, a host whose DNS returns one public and one private IP, a 302 redirect from a public site to `http://10.0.0.1`, and a simulated **rebinding** (a stub resolver returning a public IP on the first lookup and `127.0.0.1` on the second: the request must go to the validated public IP).

## 4. Per-page extraction

| Field | Source |
|---|---|
| status, headers, timings, redirect chain | HTTP response |
| title, meta description, meta robots, canonical, hreflang, lang, viewport, charset, OG/Twitter | `<head>` |
| X-Robots-Tag, Link: rel=canonical | headers |
| H1–H6 headings in order | DOM |
| links (`a[href]`, `link[href]`, `img[src]`, `script[src]`), anchor, `rel` | DOM, resolved against `<base>` |
| visible text, word count, 64-bit simhash | DOM without script/style/nav (heuristic) |
| structured data | `script[type="application/ld+json"]`, `itemscope/itemprop`, `typeof/property` |
| images without `alt`, size | DOM |
| mixed content | `http:` resources on an `https:` page |

## 5. MVP check catalogue (own)

Severity: **E** error, **W** warning, **N** notice. Weight 1–10 (used for score and priority). This is the original design; the implemented catalogue (58 checks) lives in `Audit::Catalog`, and the user-facing texts in `config/locales/checks.{en,es}.yml`.

| Category | Key | Sev | Weight | Rule |
|---|---|---|---|---|
| Crawlability | `http.4xx` | E | 9 | linked internal page returning 4xx |
| | `http.5xx` | E | 10 | 5xx |
| | `http.timeout` | E | 7 | no response within the time limit |
| | `redirect.chain` | W | 4 | >1 hop |
| | `redirect.loop` | E | 8 | loop |
| | `redirect.temporary` | N | 2 | 302/307 on internal links |
| | `robots.blocked_internal_linked` | W | 4 | URL linked internally but blocked by robots.txt |
| | `sitemap.non_200` | W | 5 | sitemap URL that does not return 200 |
| | `sitemap.noindex` | W | 5 | sitemap URL that is not indexable |
| | `sitemap.missing` | W | 3 | no discoverable sitemap |
| | `page.orphan` | W | 4 | in the sitemap but with no inbound internal links |
| | `page.deep` | N | 2 | depth > 4 clicks |
| Indexability | `robots.noindex` | N | 1 | noindex (informational; W if it is in the sitemap) |
| | `canonical.missing` | N | 2 | no canonical |
| | `canonical.to_non200` | E | 7 | canonical points to 3xx/4xx/5xx |
| | `canonical.to_noindex` | E | 7 | canonical points to a noindex page |
| | `canonical.multiple` | E | 6 | more than one conflicting canonical (head and header included) |
| | `canonical.relative_or_invalid` | W | 3 | invalid or relative canonical |
| | `canonical.chain` | W | 4 | canonical → page with another canonical |
| | `hreflang.no_return` | W | 4 | missing reciprocal link |
| | `hreflang.invalid_code` | W | 4 | invalid ISO code |
| Metadata | `title.missing` | E | 8 | no title or empty |
| | `title.duplicate` | E | 6 | same title on ≥2 indexable pages |
| | `title.too_long` | W | 2 | > 60 characters (≈ 580 px) |
| | `title.too_short` | N | 1 | < 15 characters |
| | `title.multiple` | W | 3 | more than one `<title>` |
| | `meta_description.missing` | W | 3 | no meta description |
| | `meta_description.duplicate` | W | 4 | duplicated across indexable pages |
| | `meta_description.length` | N | 1 | <70 or >160 characters |
| Content | `h1.missing` | W | 4 | no H1 |
| | `h1.multiple` | N | 1 | several H1s |
| | `headings.skipped_level` | N | 1 | skipped level (H2 → H4) |
| | `h1.equals_title` | N | 1 | informational |
| | `content.thin` | W | 3 | < 200 words on an indexable page (configurable threshold) |
| | `content.duplicate` | W | 5 | simhash Hamming distance ≤ 3 between indexable pages |
| | `images.missing_alt` | W | 2 | images without `alt` |
| Links | `links.internal_broken` | E | 9 | internal link to 4xx/5xx |
| | `links.external_broken` | W | 3 | broken external link (HEAD check, limited to 1 per host per second) |
| | `links.internal_nofollow` | W | 3 | `nofollow` on an internal link |
| | `links.to_redirect` | N | 2 | internal link to a redirecting URL |
| | `links.too_many` | N | 1 | > 300 links on the page |
| Structured data | `schema.invalid_json` | E | 6 | unparseable JSON-LD |
| | `schema.unknown_type` | W | 3 | `@type` not in the schema.org vocabulary |
| | `schema.missing_required` | W | 4 | properties required for rich results are missing (own rules derived from Google Search Central's public documentation: Article, Product, BreadcrumbList, FAQPage, Organization, LocalBusiness, Event, Recipe…) |
| | `schema.none` | N | 1 | page without structured data |
| HTTPS | `https.not_used` | E | 8 | page served over http |
| | `https.mixed_content` | W | 5 | http resources on an https page |
| | `https.http_links` | N | 2 | internal links to the http version |
| | `https.cert_invalid` | E | 9 | invalid/expired certificate |
| Mobile | `mobile.viewport_missing` | W | 5 | no meta viewport |
| Performance | `perf.lcp_poor` | W | 5 | LCP > 4 s (PSI) |
| | `perf.cls_poor` | W | 4 | CLS > 0.25 |
| | `perf.inp_poor` | W | 4 | INP > 500 ms (CrUX, if available) |
| | `perf.score_low` | N | 2 | Lighthouse score < 50 |
| | `perf.slow_response` | N | 2 | HTML download by the crawler > 1.5 s (formerly `perf.slow_ttfb`; see ADR 0005) |
| | `page.too_large` | N | 2 | HTML > 2 MB |
| GEO / AI search | `ai.bots_blocked` | W | 3 | robots.txt blocks relevant AI bots (list kept in config; informational: it may be intentional) |
| | `ai.llms_txt_missing` | N | 1 | no `/llms.txt` (proposed standard, impact not guaranteed) |
| | `ai.content_requires_js` | W | 4 | (with JS rendering) rendered visible text ≫ text in the raw HTML |

The "how to fix it" texts are written from scratch in English and Spanish; no third-party descriptions are copied.

## 6. Scoring and prioritisation (own formulas)

Implemented in `Audit::Scoring`. The final version and its rationale are in [ADR 0007](adr/0007-scoring-and-priority.md):

```
coverage = 1 if the check is site-wide; otherwise min(1, affected pages / crawled pages)
penalty  = weight × factor (error/warning 1, notice 0.25) × √coverage
category = 100 × (1 − Σ penalty / Σ weight × factor)
health   = Σ category × category weight / 100
priority = 10 × weight × factor × (0.5 × coverage + 0.5 × page importance)
```

Category weights: crawlability 22, indexability 18, links 14, metadata 14, content 10, HTTPS 6, structured data 5, mobile 5, performance 3 and AI search 3. A page's importance is its internal PageRank relative to the maximum (or, failing that, its inbound links); once GSC is available it will be combined with impressions.

## 7. Performance with PageSpeed Insights

- Sample: home page + top-N URLs by internal PageRank (20 by default), one per detected URL template (grouping by path pattern), `strategy=mobile` and optionally `desktop`.
- Call: `GET https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=…&strategy=mobile&category=performance&category=seo&category=accessibility&key=…`. LCP, CLS, TBT, FCP, TTFB, score and opportunities are stored; if the response includes `loadingExperience` (CrUX), field INP/LCP/CLS (p75) as well.
- Internal rate limit: 1 req/s and a configurable daily maximum (the free quota is generous; see 05).
- PSI runs Lighthouse on Google's servers against the public URL → no SSRF risk on our side, but it only works with public URLs.

## 8. Exportable reports

- **CSV**: pages (all columns), issues (check × URL), broken links, duplicates.
- **XLSX** (`caxlsx`): Summary, Prioritised issues, Pages, Broken links, Duplicates, Schema and Performance sheets.
- **PDF** (HTML → PDF with Grover/Playwright in the renderer, or `prawn`): executive summary with the health score, top-10 issues by priority with explanation and "how to fix it", per-category charts, and comparison with the previous crawl if there is one.
- Generated asynchronously; downloaded through a short-lived URL. *Implemented with Prawn and owner-only downloads; reports are written in the language of the user who requested them (ADR 0009, ADR 0010).*

## 9. MVP frontend

Screens: Sign in · Projects · Domain (verification) · New crawl (form with limits) · Crawl progress (live via Turbo Streams) · Audit summary (score, categories, top issues) · Issue list → affected pages · Page explorer (filterable table) · Page detail · Duplicates · Performance · Exports. The interface is in English by default, with Spanish available from the top bar (ADR 0010).

## 10. Testing strategy

| Level | Tools | What it covers |
|---|---|---|
| Unit | RSpec | SafeHttp (SSRF table), robots.txt parser (RFC 9309 cases), URL normalisation, each check with an HTML fixture, simhash, score formulas |
| Integration | RSpec + **local fixture site** (Rack app with pages, redirects, 404, sitemap, robots) + WebMock for PSI | End-to-end crawl → exact expected issues |
| Request specs | RSpec | HTML controllers: user isolation, sign-in redirects, 422 forms, limits, locale switching |
| System specs | Capybara + Cuprite | Sign in, projects and domains, crawl form, live progress, issues, language switch |
| Security | RSpec + `brakeman` + `bundler-audit` + `importmap audit` in CI | |

Note: the fixture site runs on localhost, which SafeHttp blocks. In `test` an explicit resolver/allowlist is injected for the fixture host only; that exception does not exist in any other environment (checked by a spec).
