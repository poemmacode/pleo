# ADR 0002 — Fijaciones de versión por Ruby 3.3.0

Fecha: 2026-10-16 · Estado: aceptada, con revisión pendiente

## Contexto

Ruby 3.3.0 (la instalada) tiene un bug del parser con parámetros anónimos usados dentro de bloques, corregido en 3.3.1. Afecta a `connection_pool` 3.x (dependencia de Sidekiq) y a Action View de Rails 8.1. Además `json` 3.x eliminó opciones que ActiveSupport 8.0.5 todavía pasa (`quirks_mode`).

Brakeman avisa de que el soporte de Rails 8.0 termina el **2026-11-07**.

## Decisión

- Rails 8.0.5.1, `connection_pool ~> 2.5`, `json ~> 2.10`.
- La CI ejecuta Brakeman con `--except EOLRails`; cualquier otro aviso rompe el build.

## Pendiente (antes del 2026-11-07)

1. Instalar Ruby ≥ 3.3.1 (recomendado 3.4.x) y actualizar `.tool-versions` y la CI.
2. Subir a Rails 8.1 (`load_defaults 8.1`) y quitar las tres fijaciones.
3. Quitar `--except EOLRails` de la CI.
