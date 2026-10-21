# SEO Platform — design documentation

A **personal, independent, non-commercial** SEO platform. It takes the publicly observable features of Semrush as a *product* reference, but all implementation, data and algorithms are our own or come from authorised sources. No third-party code, databases, texts, proprietary metrics or assets are copied.

Status: design approved on 2026-10-16. MVP (epics 0, A–F) implemented; see `../README.md`.

| Document | Contents |
|---|---|
| [01-product-analysis.md](01-product-analysis.md) | Phase 1: method, evidence, limits and inventory of the 8 modules |
| [02-architecture.md](02-architecture.md) | Phase 2: stack, diagram, modules, database schema, routes, roadmap |
| [03-mvp-crawler.md](03-mvp-crawler.md) | Phase 3: technical crawler design, safety (SSRF / DNS rebinding), check catalogue |
| [04-backlog.md](04-backlog.md) | MVP backlog and later phases with acceptance criteria |
| [05-data-sources-costs.md](05-data-sources-costs.md) | Authorised data sources, quotas and estimated costs |
| [06-workflow.md](06-workflow.md) | Phase 4: repository state, proposed location, workflow, pending decisions |
| [deploy.md](deploy.md) | Deploying to Render's free plan |
| [api/openapi.yaml](api/openapi.yaml) | JSON API specification (OpenAPI 3.1), rendered at `/api/docs` |
| [adr/](adr/) | Architecture decisions taken during implementation |

## Principles

1. **Own and free first**: own crawler + Google Search Console + PageSpeed Insights/CrUX before paid APIs.
2. **Authorised data**: only official APIs or licensed providers. No scraping of Google SERPs or chatbot interfaces (it breaks their terms).
3. **Responsible crawling**: robots.txt, rate limits, crawl budget, an identifiable User-Agent, and full crawls only for domains the user has verified.
4. **Secure by default**: the crawler is an HTTP client that accepts user URLs → it is treated as an SSRF surface from day one.
5. **Vertical slices**: each module is delivered end to end (DB → job → controller → UI → tests) before the next one starts.
