# Phase 4 — Workflow before coding

## 1. Inspection of the existing repository

| Item | State (16 Oct 2026) |
|---|---|
| `/Users/joss/Documents/claude-apps` | **Not a git repository.** |
| `rea/` | Incomplete clone of the REA repo (Node/TypeScript). Not part of this project; left untouched. |
| `rea.tar.gz` (13 MB) | Archive of the same clone. Left untouched. |
| SEO project | **No code yet.** Only this `seo-platform/docs/` folder. |

Local tools found: Ruby 3.3.0, Rails 8.0.5, Node 22.19.0 (asdf; the app's PATH starts with Node 14 from nvm, so scripts must pin the version with `.tool-versions`), PostgreSQL 15.3 (client; server to be checked), Redis 7.0.12, Google Chrome (usable by Playwright in development).

## 2. Existing architecture and dependencies

There is no previous architecture to respect: the design in [02-architecture.md](02-architecture.md) starts from scratch. The only "dependency" is the local environment above.

## 3. Proposed project location

```
/Users/joss/Documents/claude-apps/seo-platform/     ← its own git repository (git init here)
├── .tool-versions          ruby 3.3.x, nodejs 22.19.0
├── docker-compose.yml      postgres 16, redis 7 (and smokescreen in iteration 1.1)
├── app/, config/, spec/    Rails 8 monolith with Hotwire (ADR 0006; previously api/ + web/)
├── renderer/               (iteration 1.1) Node + Playwright
├── deploy/                 Kamal config / IaC
└── docs/                   this documentation
```

Reasons: it sits next to the documentation already written, separate from `rea/`, and as an independent repo (not inside `claude-apps`, which is not a git repo and holds another project). Alternative: move it to `~/Documents/seo-platform` if it should live outside `claude-apps`.

## 4. Vertical-slice flow

For each story in the [backlog](04-backlog.md):

1. Branch `feat/<id>-<slug>`.
2. Migration + model + model spec.
3. Service/job with unit specs (HTML fixtures or recorded responses).
4. Controller + request spec.
5. Hotwire view + HTML request spec (and a system spec if there is interaction). User-facing text goes through I18n in both `en` and `es` (ADR 0010).
6. If it touches the main flow, update the end-to-end system spec.
7. Green CI → merge.

MVP order: 0 → A → B → C → D → E → F, with G in parallel from B onwards.

## 5. Documentation to maintain

`README.md` (5-minute setup), `docs/deploy.md`, a limitations section (what it does not do and why: clickstream, backlinks at scale, API vs AI app differences), `docs/adr/` (architecture decisions: separate renderer, Smokescreen, modular monolith, keyword provider), `CHANGELOG.md`. Documentation, comments and code are written in English.

## 6. Decisions (resolved on 2026-10-16)

Approved: MVP with technical audit + PSI only; project in `claude-apps/seo-platform` with its own git; local only for now; JS rendering in iteration 1.1. Pending: keyword provider (does not block the MVP).

Original list:

1. **Approve the MVP scope** (technical audit + PSI only, no paid APIs).
2. **Location**: `claude-apps/seo-platform/` with its own `git init` (recommended) or another path.
3. **Initial deployment**: local only for now (recommended) vs EC2 + Kamal from the start.
4. **Future keyword provider**: Google Ads Keyword Planner (free, needs an Ads account and developer token approval) vs DataForSEO (pay as you go, no paperwork). Does not block the MVP.
5. **JS rendering**: confirm it can wait for iteration 1.1 rather than the MVP.

## 7. Known limitations of the analysis

- Semrush's tools require an account; the analysis stopped at the public product pages and the Knowledge Base. No internal UI was observed.
- No Semrush data, texts or proprietary metrics were used; public figures from their marketing (database size, number of checks) are only quoted as context.
- The formulas (KD, health score, priority, visibility) are our own designs and will need calibrating with the user's real data.
