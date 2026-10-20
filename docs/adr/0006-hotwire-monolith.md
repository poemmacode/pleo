# ADR 0006 — Rails monolith with Hotwire

Date: 2026-10-17 · Status: accepted · Supersedes the `api/` + `web/` (React) part of ADR 0001

## Context

The MVP was two applications: Rails 8 in API mode (`/api/v1`, JSON) and a React 19 SPA with Vite. For a personal tool that meant two toolchains (Ruby and Node), JSON contracts duplicated in TypeScript types, header-based CSRF and a development proxy. The user asked for a single Rails monolith with a Turbo/Hotwire interface.

## Decisions

1. **One Rails app at the repository root** (previously `api/`). `web/` is removed, along with Node, Vite, Vitest and MSW.
2. **No JSON API.** The HTML controllers use the same services the API used: `Crawling::CreateCrawl`, `Crawling::Lifecycle`, `Domain::Verifier`, `Audit::Summary` and `Audit::NearDuplicates`. If an API is ever needed, it will be added as a separate namespace on top of those services.
3. **Propshaft + importmap**, no build step. Turbo and Stimulus are served from the gems. The SPA's stylesheet is kept as it was in `app/assets/stylesheets/application.css`.
4. **Turbo for navigation**:
   - Lazy frames for the page table and for each check's findings (loaded when its `<details>` opens).
   - "Load more" with Turbo Stream responses (`append`) and keyset pagination (`CrawlScoped#keyset`).
   - Confirmations with `data-turbo-confirm`.
5. **Stimulus only where it helps**:
   - `verification-method`: shows the instructions for the chosen method.
   - `domain-switch`: reloads the crawl form for the chosen domain, with its defaults and limits.
   - `autosubmit`: applies filters as they change.
   Everything else works without JavaScript.
6. **Live progress with Turbo Streams over Action Cable** (`Crawling::ProgressBroadcaster`):
   - The crawl page subscribes to `[crawl, :progress, locale]` (one stream per language since [ADR 0010](0010-internationalization.md)), and the jobs replace the `crawls/_progress` and `crawls/_audit` partials.
   - Lanes call the broadcaster after each URL, throttled: `SET NX PX 2000` in Redis, at most one broadcast every 2 s per crawl.
   - Transitions (start, pause, resume, cancel, finish, audit states and automatic pause) use `force: true`.
   - The partials depend only on the crawl, so they can be rendered outside a request. The buttons they contain work because Turbo sends the CSRF token from the `<meta>` tag in a header.
7. **Cable security**: `ApplicationCable::Connection` requires the same server-side session as the pages (signed `session_id` cookie) and rejects anonymous connections. Turbo signs stream names, so only whoever received the page can subscribe.
8. **Standard Rails CSRF** (token in forms and `<meta>`). The `csrf_token` endpoint and the manual `allow_forgery_protection` setting are gone.
9. **System specs with Cuprite** (headless Chrome over CDP) instead of Selenium. Selenium needs `chromedriver`, which was not installed and which Selenium Manager would have downloaded automatically. Cuprite uses the Chrome already present (`CHROME_PATH` in CI). In system specs Action Cable uses the `async` adapter so broadcasts reach the browser; the other specs use `test`.

## Consequences

- One suite: RSpec with HTML request specs, system specs and the unchanged domain specs.
- The public API, which nobody used yet, is gone. The design documents mark that section as superseded.
- `?domain_id=` instead of `?domain=`: `domain` is a reserved `url_for` option (the host).
