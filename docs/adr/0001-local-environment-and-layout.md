# ADR 0001 — Local environment and monorepo layout

Date: 2026-10-16 · Status: accepted; the `api/` + `web/` and React parts are superseded by [ADR 0006](0006-hotwire-monolith.md)

## Context

The development machine's Homebrew Postgres does not start (the ICU library it links against is missing) and Docker Desktop is not running. Postgres.app 15.2 and Redis 7 (brew services) are available.

## Decision

- Monorepo `seo-platform/` with `api/` (Rails) and `web/` (Vite), in its own git repository.
- `bin/db` creates and starts a PostgreSQL cluster **inside the project** (`tmp/postgres`, port 5433, 127.0.0.1 only, `trust` auth) with the Postgres.app binaries. It does not touch the global configuration.
- `docker-compose.yml` offers the same topology (Postgres 16 on 5433, Redis on 6379) for anyone with Docker.
- `bin/dev` is compatible with bash 3.2 (macOS's bash) and does not depend on foreman.
- Frontend with React 19 (the current Vite template), not 18 as the design said: there is no reason to start on an older version.
- Domain code in `app/modules/<module>/` with one namespace per folder (e.g. `SafeHttp::HostPolicy`). Core models (users, projects, domains) live in `app/models`. Packwerk is postponed until there are several modules.

## Consequences

Production will use Postgres 16 (RDS or a container); development on 15.2 uses nothing specific to 16.
