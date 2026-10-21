# ADR 0011 — Roles, public pages, JSON API and status page

Date: 2026-10-21 · Status: accepted

## Context

Until now the app had one user, created from `ADMIN_EMAIL` / `ADMIN_PASSWORD`, and no public pages apart from `/bot`. The user asked for:

- open sign-up, with the environment's account as the only admin;
- members who can only edit their own records and cannot delete anything critical;
- a public home page that presents the product's features and asks visitors to sign in;
- a documented API;
- a status page with health checks and uptime.

## Decisions

### Roles

1. **`users.role`** is `admin` or `member` (check constraint, default `member`). Sign-up always creates members. `bin/rails users:ensure` runs on every boot and:
   - makes the `ADMIN_EMAIL` account an admin;
   - demotes any other admin, so changing `ADMIN_EMAIL` moves the role;
   - keeps the admin password equal to `ADMIN_PASSWORD`. The app has no screen to change it, so the environment is the only source.

   When the password changes, every session of that account is deleted. This also covers the case where someone had registered that email address as a member before the variable was set: the account becomes the admin's, with a new password, and the earlier holder is signed out.
2. **Scope.** `User#accessible_projects` is the user's own projects for a member and `Project.all` for the admin. Every controller loads projects, domains and crawls through it, so another user's record is a 404, the same as before.
3. **What members cannot delete.** `User#can_destroy?` is the single rule, used by the HTML controllers, the API and the views (which hide the buttons). Members cannot delete:
   - projects;
   - verified domains;
   - domains that have crawls;
   - crawls or reports;
   - users.

   They can remove an unverified domain with no crawls (a typo) and revoke their own API tokens. Revoking a token is a security control, not data loss. Cancelling a crawl stays allowed because it deletes nothing. The admin can do everything, and can delete members (with their data) from `/admin/users`. The admin account itself can't be deleted there.
4. **Members can edit** their projects (rename), add and verify domains, start, pause, resume and cancel crawls, run audits and generate reports.

### Sign-up

5. **Public sign-up** at `/sign_up`, rate limited to 5 per hour per IP. It can be closed with `REGISTRATION_OPEN=false`, which hides the links and redirects to sign-in.

   Open sign-up means strangers can start crawls. What still limits them:
   - the existing crawl limits: unverified domains get 2,000 pages and 2 req/s at most, after accepting the site's terms;
   - one active crawl per host and two per user;
   - robots.txt;
   - the SafeHttp SSRF guard.

   Close sign-up if the deployment should be private.

### Public pages

6. **Home (`/`)** is public and describes only what the product actually does. Signed-in users are redirected to `/projects`. Its texts are in the locale files like the rest of the interface. English is the default and Spanish is kept so the language picker stays consistent (`config/locales/site.{en,es}.yml`).

### API

7. **JSON API at `/api/v1`** (`Api::V1::BaseController < ActionController::API`):
   - **Authentication.** Bearer tokens from *Settings → API tokens*. Each token is `seop_` + 40 base58 characters. Only its SHA-256 digest is stored, the full token is shown once, and each user can have at most 10. `last_used_at` is updated at most every 5 minutes.
   - **Rules.** The API uses the same scope and `can_destroy?` rules as the web interface. It doesn't use cookies or CSRF.
   - **Errors.** Always `{error: {code, message, details}}`, with messages in English.
   - **Rate limits.** 120 requests per minute per token. Starting crawls and verifying domains are limited to 10 per minute.
   - **Pagination.** Keyset (`after`, `limit` ≤ 200).

   Crawl creation goes through `Crawling::CreateCrawl`, like the form, so the API has the same limits and validations.
8. **The specification is the source of truth for the docs.**
   - `docs/api/openapi.yaml` (OpenAPI 3.1) is written by hand.
   - `/api/docs` renders it server-side in ERB, with no Swagger UI and no external JavaScript.
   - `/api/docs/openapi.yaml` serves the raw file.
   - `spec/requests/api/openapi_spec.rb` fails if a route under `/api/v1` is not documented or a documented path doesn't exist, and checks that every `$ref` resolves.

### Status page

9. **Status (`/status`, plus `/status.json`)** is public:
   - **Live probe.** `Monitoring::HealthProbe` checks:
     - the database (`SELECT 1`);
     - Redis (`PING`);
     - background jobs: a live Sidekiq process and queue latency under 10 minutes.

     If the database is down, the app is down. Any other failure means degraded, and the JSON answers 503 only when the app is down.
   - **History.** `Monitoring::HealthCheckJob` records an `UptimeCheck` every 5 minutes, deletes checks older than 90 days, and schedules itself again. A Redis `SET NX` key keeps a single chain however many times it is started (Sidekiq startup, or a visit to `/status` when no check is scheduled).
   - **Figures.** `Monitoring::Uptime` computes:
     - uptime and coverage for 24 h, 7 d and 30 d;
     - 30 daily bars;
     - incidents, meaning consecutive non-ok checks.
10. **Gaps are "no data", not downtime.** An app cannot record its own outage, and on Render's free plan it sleeps after 15 minutes without traffic. The page shows coverage so these gaps are visible. Real outage detection needs an external monitor pointing at `/up` or `/status.json`.

## Consequences

- `/` is no longer the projects list. Signed-in navigation starts at `/projects`.
- New tables: `api_tokens` and `uptime_checks`. New column: `users.role`.
- Sign-up is open by default. Set `REGISTRATION_OPEN=false` to keep a single-user deployment.
