# SEO Platform

Plataforma SEO personal y no comercial. El diseño completo está en [docs/](docs/README.md).

Estado: **Épicas 0, A, B y C**, más la interfaz en Hotwire. Incluye:
- autenticación, proyectos y dominios con verificación (DNS TXT, archivo o meta tag);
- cliente HTTP seguro (SafeHttp), robots.txt y límite de velocidad por host;
- crawler con descubrimiento por sitemaps y enlaces, y progreso en vivo;
- auditoría con 54 checks.

La puntuación, PageSpeed y los informes llegan con las épicas D–F.

## Estructura

Es un monolito Rails 8 con Hotwire (Turbo + Stimulus, importmap, sin Node). Ver [ADR 0006](docs/adr/0006-monolito-hotwire.md).

```
app/modules/   dominio: SafeHttp, Crawling, Audit
app/jobs/      Sidekiq: crawling (lanes, sitemaps) y audit
app/views/     HTML + Turbo Frames/Streams; app/javascript/controllers: Stimulus
bin/dev        Postgres local + Rails + Sidekiq
bin/db         clúster PostgreSQL propio del proyecto (puerto 5433, solo loopback)
docs/          análisis, arquitectura, backlog y decisiones (docs/adr/)
```

## Requisitos

- Ruby 3.3.0 (`.tool-versions`).
- PostgreSQL ≥ 15. `bin/db` usa Postgres.app si existe, o el `pg_ctl` del PATH. Alternativa: `docker compose up -d`.
- Redis 7 en `127.0.0.1:6379`, para Sidekiq, Action Cable y el límite de velocidad.
- Google Chrome, solo para los system specs.

## Puesta en marcha

```bash
bin/db start
```

```bash
bundle install && bin/rails db:prepare
```

Crea tu usuario. El registro público está deshabilitado; la contraseña se pide sin mostrarla y debe tener al menos 12 caracteres:

```bash
bin/rails users:create EMAIL=tu@correo.com
```

Arranca Rails (puerto 3000) y Sidekiq:

```bash
bin/dev
```

Abre http://127.0.0.1:3000.

## Despliegue

Render (plan gratuito) con el Blueprint [`render.yaml`](render.yaml): ver [docs/deploy.md](docs/deploy.md).

## Pruebas

```bash
bundle exec rspec
```

```bash
bin/rubocop && bin/brakeman --no-pager --except EOLRails && bin/importmap audit
```

La CI (`.github/workflows/ci.yml`) ejecuta lo mismo, más `bundle-audit`, con Postgres, Redis y Chrome.

## Rutas

| Ruta | Qué hace |
|---|---|
| `/session` | login y logout (límite de 10 intentos cada 3 min) |
| `/bot` | página pública sobre el rastreador (enlazada desde su User-Agent) |
| `/` y `/projects/:id` | proyectos, dominios (añadir, verificar, quitar) y crawls |
| `/projects/:id/crawls/new?domain_id=` | nuevo crawl; valores por defecto y límites según si el dominio está verificado |
| `/crawls/:id` | progreso en vivo, pausa, reanudación, cancelación, auditoría y tabla de páginas |
| `/crawls/:id/pages/:page_id` | detalle: campos on-page, datos estructurados, problemas y enlaces |
| `/crawls/:id/duplicates?type=title\|description\|content` | grupos de duplicados |

## Seguridad ya implementada

- Sesiones en servidor (revocables) con cookie firmada `HttpOnly; SameSite=Lax` (`Secure` en producción) y CSRF estándar de Rails.
- Action Cable solo acepta conexiones con sesión, y los streams de Turbo van firmados.
- Cada usuario solo ve sus proyectos, dominios y crawls (404 en los ajenos).
- Los dominios se normalizan (punycode, minúsculas). Se rechazan:
  - IPs en cualquier notación;
  - `localhost` y nombres internos;
  - URLs con puerto o con credenciales;
  - hosts sin dominio público registrable.

## SafeHttp (`app/modules/safe_http/`)

Toda petición saliente hacia URLs de usuarios pasa por `SafeHttp::Client`:

- Solo http/https y los puertos 80/443 (`SAFE_HTTP_ALLOWED_PORTS`); sin credenciales en la URL ni caracteres de control.
- Resolución DNS propia (A + AAAA, sin `/etc/hosts`). Se rechaza la URL si **cualquier** IP resuelta está bloqueada: rangos privados, loopback, link-local/metadatos, CGNAT, reservados, o formas IPv6 que contienen una IPv4 bloqueada.
- Conexión a la IP ya validada (anti DNS rebinding), con `Host`, SNI y certificado del hostname; se ignoran los proxies de entorno.
- Redirecciones manuales (máximo 10), revalidando cada salto. Límites de tiempo y cuerpo de 5 MB como máximo, **una vez descomprimido**.
- robots.txt según la RFC 9309, límite de velocidad por host en Redis y velocidad adaptativa.

## Crawler (`app/modules/crawling/`, `app/jobs/crawling/`)

- Dominio verificado: hasta 50 000 páginas y 10 req/s. Sin verificar: hasta 2 000 páginas y 2 req/s (por defecto 500 y 1 req/s), confirmando que los términos del sitio lo permiten. Un crawl activo por host y dos por usuario.
- `robots.txt` por host (no desactivable) y `Crawl-delay`. Si el servidor devuelve muchos 429/5xx, la velocidad se reduce y el crawl se pausa solo.
- Detalles en [ADR 0004](docs/adr/0004-crawling.md).

## Auditoría (`app/modules/audit/`)

- Se ejecuta sola al completarse el crawl. El catálogo de checks está en `Audit::Catalog`.
- El vocabulario de schema.org está en `config/schema_org/` (CC BY-SA) y se regenera con `bin/rails schema_org:refresh`.
- Para re-extraer un crawl con el extractor actual: `bin/rails audit:reextract CRAWL_ID=…`.
- Detalles en [ADR 0005](docs/adr/0005-auditoria.md).

## Limitaciones actuales

- La verificación vía Search Console llegará con esa integración.
- Ruby 3.3.0 tiene un bug del parser que obliga a fijar `connection_pool` 2.x e impide pasar a Rails 8.1. Además, `json` está fijado a 2.x por incompatibilidad con ActiveSupport 8.0.5. Ver [ADR 0002](docs/adr/0002-versiones-ruby-rails.md).
