# Fase 4 — Flujo de trabajo previo a codificar

## 1. Inspección del repositorio actual

| Elemento | Estado (16-oct-2026) |
|---|---|
| `/Users/joss/Documents/claude-apps` | **No es un repositorio git.** |
| `rea/` | Clon incompleto del repo de REA (Node/TypeScript). No forma parte de este proyecto; no se toca. |
| `rea.tar.gz` (13 MB) | Archivo del mismo clon. No se toca. |
| Proyecto SEO | **No existe código.** Solo esta carpeta `seo-platform/docs/`. |

Herramientas locales detectadas: Ruby 3.3.0, Rails 8.0.5, Node 22.19.0 (asdf; el PATH del app arranca con Node 14 de nvm, así que los scripts deben fijar la versión con `.tool-versions`), PostgreSQL 15.3 (cliente; servidor por verificar), Redis 7.0.12, Google Chrome (usable por Playwright en desarrollo).

## 2. Arquitectura y dependencias existentes

No hay arquitectura previa que respetar: el diseño de [02-arquitectura.md](02-arquitectura.md) parte de cero. La única "dependencia" es el entorno local anterior.

## 3. Ubicación propuesta del proyecto

```
/Users/joss/Documents/claude-apps/seo-platform/     ← repositorio git propio (git init aquí)
├── .tool-versions          ruby 3.3.x, nodejs 22.19.0
├── docker-compose.yml      postgres 16, redis 7 (y smokescreen en la iteración 1.1)
├── api/                    Rails 8 API (app/modules/*, spec/)
├── web/                    React + TS + Vite
├── renderer/               (iteración 1.1) Node + Playwright
├── deploy/                 Kamal config / IaC
└── docs/                   esta documentación
```

Motivos: queda junto a la documentación ya creada, separada de `rea/`, y como repo independiente (no dentro de `claude-apps`, que no es git y contiene otro proyecto). Alternativa: moverlo a `~/Documents/seo-platform` si se prefiere fuera de `claude-apps`.

## 4. Flujo por vertical slice

Para cada historia del [backlog](04-backlog.md):

1. Rama `feat/<id>-<slug>`.
2. Migración + modelo + spec de modelo.
3. Servicio/job con specs unitarias (fixtures HTML o respuestas grabadas).
4. Endpoint + request spec (rswag → OpenAPI).
5. Pantalla React + test de componente (MSW).
6. Si toca el flujo principal, actualizar el E2E de Playwright.
7. CI en verde → merge.

Orden del MVP: 0 → A → B → C → D → E → F, con G en paralelo desde B.

## 5. Documentación a mantener

`README.md` (setup en 5 minutos), `docs/deploy.md`, `docs/limitations.md` (qué no hace y por qué: clickstream, backlinks a escala, diferencias API vs apps de IA), `docs/adr/` (decisiones de arquitectura: renderer separado, Smokescreen, monolito modular, proveedor de keywords), `CHANGELOG.md`.

## 6. Decisiones (resueltas el 2026-10-16)

Aprobado: MVP solo con auditoría técnica + PSI; proyecto en `claude-apps/seo-platform` con git propio; solo local por ahora; render JS en la iteración 1.1. Pendiente: proveedor de keywords (no bloquea el MVP).

Lista original:

1. **Aprobar el alcance del MVP** (solo auditoría técnica + PSI, sin APIs de pago).
2. **Ubicación**: `claude-apps/seo-platform/` con `git init` propio (recomendado) u otra ruta.
3. **Despliegue inicial**: solo local por ahora (recomendado) vs EC2 + Kamal desde el principio.
4. **Proveedor de keywords futuro**: Google Ads Keyword Planner (gratis, requiere cuenta Ads y aprobación del developer token) vs DataForSEO (pago por uso, sin trámites). No bloquea el MVP.
5. **Render JS**: confirmar que puede ir en la iteración 1.1 y no en el MVP.

## 7. Limitaciones conocidas del análisis

- Las herramientas de Semrush requieren cuenta; el análisis se detuvo en las páginas públicas de producto y la Knowledge Base. No se observó ninguna UI interna.
- No se usaron datos, textos ni métricas propietarias de Semrush; las cifras públicas de su marketing (tamaño de bases de datos, nº de checks) solo se citan como contexto.
- Fórmulas (KD, health score, prioridad, visibilidad) son diseños propios y deberán calibrarse con datos reales del usuario.
