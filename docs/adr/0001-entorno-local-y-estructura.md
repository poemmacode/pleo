# ADR 0001 — Entorno local y estructura del monorepo

Fecha: 2026-10-16 · Estado: aceptada

## Contexto

El Postgres de Homebrew de la máquina de desarrollo no arranca (falta la librería ICU que enlaza) y Docker Desktop no está en marcha. Sí hay Postgres.app 15.2 y Redis 7 (brew services).

## Decisión

- Monorepo `seo-platform/` con `api/` (Rails) y `web/` (Vite) y su propio repositorio git.
- `bin/db` crea y arranca un clúster PostgreSQL **dentro del proyecto** (`tmp/postgres`, puerto 5433, solo 127.0.0.1, auth `trust`) con los binarios de Postgres.app. No toca la configuración global.
- `docker-compose.yml` ofrece la misma topología (Postgres 16 en 5433, Redis en 6379) para quien tenga Docker.
- `bin/dev` es bash 3.2-compatible (la bash de macOS) y no depende de foreman.
- Frontend con React 19 (la plantilla actual de Vite), no 18 como decía el diseño: no hay razón para empezar en una versión anterior.
- Código de dominio en `app/modules/<modulo>/` con namespace por carpeta (p. ej. `SafeHttp::HostPolicy`). Los modelos del núcleo (usuarios, proyectos, dominios) viven en `app/models`. Packwerk se pospone hasta que existan varios módulos.

## Consecuencias

Producción usará Postgres 16 (RDS o contenedor); el desarrollo en 15.2 no usa nada específico de 16.
