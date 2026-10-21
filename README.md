# SEO Platform

A technical SEO audit platform. The full design is in [docs/](docs/README.md).

Status: **MVP complete (epics 0, A–F)** with a Hotwire interface, in English by default and Spanish on request. It includes:
- a public home page, open sign-up and two roles: the `ADMIN_EMAIL` account is the only admin, members edit only their own records and cannot delete anything critical ([ADR 0011](docs/adr/0011-roles-public-pages-api-status.md));
- projects and domains with verification (DNS TXT, file or meta tag);
- a safe HTTP client (SafeHttp), robots.txt and per-host rate limiting;
- a crawler with sitemap and link discovery, and live progress;
- an audit with 58 checks;
- overall and per-category health scores, compared with the previous crawl, and issues sorted by priority;
- mobile performance with PageSpeed Insights (Lighthouse, plus real-user Core Web Vitals from CrUX) on a sample of pages; needs `PAGESPEED_API_KEY` (see [docs/deploy.md](docs/deploy.md));
- exportable reports: pages and issues as CSV, a full Excel report and a PDF executive summary;
- an EN/ES language picker in the top bar, saved per user ([ADR 0010](docs/adr/0010-internationalization.md));
- a JSON API (`/api/v1`) with personal tokens, documented in OpenAPI 3.1 ([`docs/api/openapi.yaml`](docs/api/openapi.yaml), rendered at `/api/docs`);
- a public status page (`/status`, `/status.json`) with live health checks and uptime history.

Next on the roadmap ([docs/02-architecture.md](docs/02-architecture.md) §7): Search Console and GA4, keywords, rank tracking, competitors, GEO and backlinks.

## Layout

A Rails 8 monolith with Hotwire (Turbo + Stimulus, importmap, no Node). See [ADR 0006](docs/adr/0006-hotwire-monolith.md).

```
app/modules/   domain: SafeHttp, Crawling, Audit, Performance, Reports, Monitoring
app/jobs/      Sidekiq: crawling (lanes, sitemaps), audit and reports
app/views/     HTML + Turbo Frames/Streams; app/javascript/controllers: Stimulus
config/locales en/es interface texts; checks.{en,es}.yml for the audit checks
bin/dev        local Postgres + Rails + Sidekiq
bin/db         project-local PostgreSQL cluster (port 5433, loopback only)
docs/          analysis, architecture, backlog and decisions (docs/adr/)
```

## Requirements

- Ruby 3.3.0 (`.tool-versions`).
- PostgreSQL ≥ 15. `bin/db` uses Postgres.app if present, or the `pg_ctl` on the PATH. Alternative: `docker compose up -d`.
- Redis 7 on `127.0.0.1:6379`, for Sidekiq, Action Cable and rate limiting.
- Google Chrome, only for the system specs.

## Getting started

```bash
bin/db start
```

```bash
bundle install && bin/rails db:prepare
```

Create the admin. It is the only admin and its password always comes from the environment (at least 12 characters):

```bash
ADMIN_EMAIL=you@example.com ADMIN_PASSWORD='a long password' bin/rails users:ensure
```

Other people sign up at `/sign_up` as members. `bin/rails users:create EMAIL=…` also creates a member from the terminal.

Start Rails (port 3000) and Sidekiq:

```bash
bin/dev
```

Open http://127.0.0.1:3000.

## Deployment

Render (free plan) with the [`render.yaml`](render.yaml) Blueprint: see [docs/deploy.md](docs/deploy.md).

## Tests

```bash
bundle exec rspec
```

```bash
bin/rubocop && bin/brakeman --no-pager --except EOLRails && bin/importmap audit
```

CI (`.github/workflows/ci.yml`) runs the same, plus `bundle-audit`, with Postgres, Redis and Chrome.

## Routes

| Route | What it does |
|---|---|
| `/` | public home page; signed-in users go to `/projects` |
| `/sign_up` | create a member account (5 per hour per IP; off with `REGISTRATION_OPEN=false`) |
| `/session` | sign in and out (limited to 10 attempts every 3 min) |
| `/locale` | switch the interface language (EN/ES) |
| `/bot` | public page about the crawler (linked from its User-Agent) |
| `/status`, `/status.json` | public status: live health of database, Redis and jobs, uptime and incidents |
| `/api/docs` | public API reference (`/api/docs/openapi.yaml` for the raw spec) |
| `/api/v1/…` | JSON API with `Authorization: Bearer <token>` |
| `/settings/api_tokens` | create and revoke your API tokens |
| `/admin/users` | admin only: list users and delete members |
| `/projects` and `/projects/:id` | projects (create, rename), domains (add, verify, remove) and crawls |
| `/projects/:id/crawls/new?domain_id=` | new crawl; defaults and limits depend on whether the domain is verified |
| `/crawls/:id` | live progress, pause, resume, cancel, audit, performance, reports and page table |
| `/crawls/:id/pages/:page_id` | detail: on-page fields, structured data, issues and links |
| `/crawls/:id/duplicates?type=title\|description\|content` | duplicate groups |
| `/crawls/:id/reports` | generate and download CSV, Excel and PDF reports |

## Security already in place

- Server-side (revocable) sessions with a signed `HttpOnly; SameSite=Lax` cookie (`Secure` in production) and standard Rails CSRF.
- Action Cable only accepts authenticated connections, and Turbo streams are signed.
- Each member only sees their own projects, domains and crawls (404 for anyone else's); the admin sees all of them.
- Members cannot delete projects, verified or crawled domains, crawls or users (`User#can_destroy?`); the admin can.
- API tokens are stored as SHA-256 digests and shown once; the API applies the same rules and is rate limited per token.
- Domains are normalised (punycode, lowercase). Rejected:
  - IPs in any notation;
  - `localhost` and internal names;
  - URLs with a port or credentials;
  - hosts without a public registrable domain.

## SafeHttp (`app/modules/safe_http/`)

Every outbound request to user URLs goes through `SafeHttp::Client`:

- Only http/https and ports 80/443 (`SAFE_HTTP_ALLOWED_PORTS`); no credentials in the URL and no control characters.
- Own DNS resolution (A + AAAA, no `/etc/hosts`). The URL is rejected if **any** resolved IP is blocked: private ranges, loopback, link-local/metadata, CGNAT, reserved, or IPv6 forms that contain a blocked IPv4.
- Connects to the already validated IP (anti DNS rebinding), with the hostname's `Host`, SNI and certificate; environment proxies are ignored.
- Manual redirects (10 at most), re-validating each hop. Time limits, and a 5 MB body limit applied **after decompression**.
- robots.txt per RFC 9309, per-host rate limiting in Redis and an adaptive rate.

## Crawler (`app/modules/crawling/`, `app/jobs/crawling/`)

- Verified domain: up to 50,000 pages and 10 req/s. Unverified: up to 2,000 pages and 2 req/s (500 and 1 req/s by default), after confirming the site's terms allow it. One active crawl per host and two per user.
- `robots.txt` per host (cannot be switched off) and `Crawl-delay`. If the server returns many 429/5xx, the rate drops and the crawl pauses itself.
- Details in [ADR 0004](docs/adr/0004-crawling.md).

## Audit (`app/modules/audit/`)

- Runs automatically when the crawl completes. The check catalogue is in `Audit::Catalog`; the check texts are in `config/locales/checks.{en,es}.yml`.
- The schema.org vocabulary is in `config/schema_org/` (CC BY-SA) and is regenerated with `bin/rails schema_org:refresh`.
- To re-extract a crawl with the current extractor: `bin/rails audit:reextract CRAWL_ID=…`.
- Details in [ADR 0005](docs/adr/0005-audit.md).

## Current limitations

- Verification through Search Console will come with that integration.
- Ruby 3.3.0 has a parser bug that forces pinning `connection_pool` 2.x and blocks the move to Rails 8.1. `json` is also pinned to 2.x because of an incompatibility with ActiveSupport 8.0.5. See [ADR 0002](docs/adr/0002-ruby-rails-versions.md).
