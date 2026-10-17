# SEO Platform

Plataforma SEO personal y no comercial. Diseño completo en [docs/](docs/README.md).

Estado: **Épicas 0 y A**: autenticación, proyectos y dominios con verificación (DNS TXT, archivo o meta tag); cliente HTTP seguro (SafeHttp), robots.txt y límite de velocidad por host. El crawler llega con las épicas B–F.

## Estructura

```
api/      Rails 8 API (Ruby 3.3, PostgreSQL, Sidekiq)
web/      React 19 + TypeScript + Vite
bin/dev   arranca todo en local
bin/db    clúster PostgreSQL propio del proyecto (puerto 5433, solo loopback)
docs/     análisis, arquitectura, backlog y decisiones (docs/adr/)
```

## Requisitos

- Ruby 3.3.0 y Node 22.19.0 (ver `.tool-versions`; con asdf: `asdf install`)
- PostgreSQL ≥ 15: `bin/db` usa Postgres.app si existe, o el `pg_ctl` del PATH. Alternativa: `docker compose up -d`
- Redis 7 en `127.0.0.1:6379` (`brew services start redis` o `docker compose up -d redis`)

## Puesta en marcha

```bash
bin/db start
```

```bash
cd api && bundle install && bin/rails db:prepare
```

```bash
cd web && npm install
```

Crea tu usuario (el registro público está deshabilitado; pide la contraseña sin mostrarla, mínimo 12 caracteres):

```bash
cd api && bin/rails users:create EMAIL=tu@correo.com
```

Arranca API (3000), Sidekiq y web (5173):

```bash
bin/dev
```

Abre http://127.0.0.1:5173. Vite hace de proxy de `/api` hacia Rails, así que la cookie de sesión es del mismo origen.

## Pruebas

```bash
cd api && bundle exec rspec && bin/rubocop && bin/brakeman --no-pager --except EOLRails
```

```bash
cd web && npm run lint && npm run build && npm test
```

La CI (`.github/workflows/ci.yml`) ejecuta lo mismo más `bundle-audit` y `npm audit`.

## API (v1)

Todas las respuestas usan `{ data, meta }` o `{ errors: [{ code, detail, field }] }`. Las peticiones que modifican estado requieren la cabecera `X-CSRF-Token` (obtenida en `GET /api/v1/csrf_token` o en `meta.csrf_token` al iniciar sesión).

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/v1/csrf_token` | token CSRF |
| POST / GET / DELETE | `/api/v1/session` | login (`email`, `password`) / usuario actual / logout |
| GET / POST | `/api/v1/projects` | listar / crear (`project: { name }`) |
| GET / PATCH / DELETE | `/api/v1/projects/:id` | detalle / renombrar / eliminar |
| GET / POST | `/api/v1/projects/:id/domains` | listar / añadir (`domain: { host }`) |
| GET / DELETE | `/api/v1/domains/:id` | detalle / quitar |
| POST | `/api/v1/domains/:id/verify` | verificar (`method`: `dns_txt`, `html_file` o `meta`) |

## Seguridad ya implementada

- Sesiones en servidor (revocables) con cookie firmada `HttpOnly; SameSite=Lax` (`Secure` en producción); CSRF obligatorio.
- Límite de 10 intentos de login cada 3 min y 10 verificaciones por minuto (memoria del proceso; pasar a Redis si hay varios procesos).
- Cada usuario solo ve sus proyectos y dominios (404 en los ajenos).
- Los dominios se normalizan (punycode, minúsculas) y se rechazan IPs en cualquier notación (decimal, octal, hex, IPv6), `localhost`, nombres internos (`.local`, `.internal`, metadatos de nube), puertos, credenciales en la URL y hosts sin dominio público registrable.

## SafeHttp (`api/app/modules/safe_http/`)

Toda petición saliente hacia URLs de usuarios pasa por `SafeHttp::Client`:

- Solo http/https, puertos 80/443 (`SAFE_HTTP_ALLOWED_PORTS`), sin credenciales en la URL ni caracteres de control.
- DNS propio (A + AAAA, sin `/etc/hosts`); se rechaza si **cualquier** IP está en rangos privados, loopback, link-local/metadatos, CGNAT, reservados o en formas IPv6 que llevan una IPv4 bloqueada.
- Conexión a la IP ya validada (anti DNS rebinding) con `Host`/SNI/certificado del hostname; ignora proxies de entorno.
- Redirecciones manuales (máx. 10), cada salto revalidado; límites de tiempo de conexión, de lectura y total; cuerpo máx. 5 MB **descomprimido**.
- `Robots::Fetcher`/`Parser`: RFC 9309 (grupos, longest-match, `*`, `$`, 4xx → todo permitido, 5xx/429/error → todo bloqueado).
- `HostRateLimiter`: espaciado por host en Redis compartido por todos los workers; `RetryAfter`; `AdaptiveRate` (reduce a la mitad con >20 % de errores, pausa tras 3 reducciones).

Las pruebas usan Redis db 15 (`TEST_REDIS_URL`) y un servidor HTTP local en 127.0.0.1, que solo se permite en el entorno `test`.

## Limitaciones actuales

- La verificación vía Search Console llegará con esa integración.
- Ruby 3.3.0 tiene un bug del parser que obliga a fijar `connection_pool` 2.x y bloquea Rails 8.1; `json` está fijado a 2.x por incompatibilidad con ActiveSupport 8.0.5. Ver [docs/adr/0002](docs/adr/0002-versiones-ruby-rails.md).
