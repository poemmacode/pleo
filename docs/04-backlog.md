# Backlog

Formato: **ID · historia** — criterios de aceptación (CA). Estimación en días-persona (d). Cada épica es una *vertical slice* que termina con API + UI + tests en verde.

## MVP

### Épica 0 — Esqueleto (≈5 d)

- **0.1 · Monorepo inicial** — CA: `seo-platform/api` (Rails 8 API, Postgres, RSpec) y `seo-platform/web` (Vite React TS, Vitest) arrancan con un comando (`bin/dev`); `docker compose up` levanta Postgres y Redis; README con setup.
- **0.2 · CI** — CA: GitHub Actions ejecuta RSpec, Vitest, rubocop, eslint, brakeman, bundler-audit; falla si alguno falla.
- **0.3 · Autenticación** — CA: registro deshabilitado por defecto (usuario creado por `bin/rails users:create`); login/logout por cookie de sesión `HttpOnly; Secure; SameSite=Lax`; CSRF protegido; endpoints sin sesión → 401.
- **0.4 · Proyectos y dominios** — CA: CRUD de proyectos; añadir dominio normaliza el host (punycode, minúsculas, sin `www.` opcional) y rechaza IPs y hosts bloqueados.
- **0.5 · Verificación de dominio** — *Implementado solo DNS TXT; archivo y meta se añaden en A.1 porque requieren SafeHttp.* CA: métodos DNS TXT (`seo-platform-verify=<token>`), archivo `/.well-known/seo-platform-<token>.txt` y meta tag; verificar consulta vía SafeHttp/DNS; token único por dominio; éxito fija `verified_at`; fallo devuelve 422 con motivo.

### Épica A — SafeHttp y robots (≈6 d)

- **A.1 · Cliente HTTP seguro** — CA: todos los casos de la tabla SSRF de [03 §3.3](03-mvp-crawler.md) se rechazan con `UnsafeTargetError`; la conexión usa la IP validada (spec con resolver stub de rebinding); TLS verifica hostname; límites de tamaño/tiempo/redirects aplicados; 100 % de cobertura de ramas en el módulo.
- **A.2 · Parser robots.txt (RFC 9309)** — CA: pasa la batería de casos de la RFC (grupos por UA, longest-match, `*`, `$`, `Allow` vs `Disallow` empatados → allow); 5xx/timeout ⇒ disallow all; 4xx ⇒ allow all; extrae `Sitemap:` y `Crawl-delay`.
- **A.3 · Rate limiting por host** — CA: token bucket en Redis; con `rps=2` y 10 workers, un test de integración mide ≤ 2 req/s ±10 % al host fixture; `Retry-After` respetado.
- **A.4 · Autoprotección ante sobrecarga** — CA: si >20 % de respuestas en 60 s son 429/5xx, el rps se divide entre 2; tras 3 reducciones el crawl pasa a `paused` con motivo visible.

### Épica B — Crawling (≈8 d)

- **B.1 · Crear/controlar crawl** — CA: `POST /crawls` valida config contra límites (verificado/no verificado); devuelve 202; pause/resume/cancel cambian estado y detienen la emisión de nuevas peticiones en < 5 s.
- **B.2 · Descubrimiento por sitemaps** — CA: encuentra sitemaps en robots.txt y `/sitemap.xml`; soporta índices anidados (máx. profundidad 3), `.gz`, y >50k URLs por paginación de índices; URLs fuera de scope se ignoran con contador.
- **B.3 · Descubrimiento por enlaces** — CA: BFS respetando `max_depth`, include/exclude, scope y robots; sin duplicados (constraint único `crawl_id,url_hash`); normalización según 03 §2.
- **B.4 · Fetch y almacenamiento** — CA: cada URL produce exactamente un registro en `pages` o un `skip_reason`; redirects registrados en `redirect_chain`; el crawl termina (`completed`) cuando no quedan pendientes o se alcanza `max_pages`, y nunca supera `max_pages`.
- **B.5 · Progreso** — CA: `GET /crawls/:id` refleja descubiertas/rastreadas/fallidas con retraso ≤ 5 s.

### Épica C — Extracción y checks (≈10 d)

- **C.1 · Extracción on-page** — CA: con un set de ≥20 fixtures HTML (incl. HTML malformado, `<base>`, múltiples titles, canonical en header y en head), los campos de 03 §4 coinciden con lo esperado.
- **C.2 · Enlaces y estados** — CA: cada enlace interno resuelve `to_page_id` y `status_code`; enlaces externos se verifican con HEAD (fallback GET con rango) limitados a 1 req/s por host externo y máx. 1 000 por crawl.
- **C.3 · Datos estructurados** — CA: extrae JSON-LD, Microdata y RDFa; detecta JSON inválido; valida `@type` contra un snapshot versionado del vocabulario schema.org (descargado de schema.org, licencia CC BY-SA) y propiedades requeridas para ≥8 tipos.
- **C.4 · Duplicados** — CA: titles y descriptions duplicados se agrupan por hash exacto (normalizado: trim, espacios, minúsculas); contenido casi duplicado por simhash (Hamming ≤ 3); solo cuentan páginas indexables con 200.
- **C.5 · Catálogo de checks** — CA: todos los checks de 03 §5 implementados como clases con spec propia (fixture positivo y negativo); `check_definitions` sembrado con textos en español.
- **C.6 · Checks de sitio** — CA: huérfanas, profundidad, PageRank interno (20 iteraciones, damping 0,85) calculados en `FinalizeCrawlJob` en < 60 s para 50k páginas en la máquina de desarrollo.

### Épica D — Score y priorización (≈3 d)

- **D.1 · Health score** — CA: fórmula de 03 §6 implementada; tests con escenarios conocidos (sitio perfecto = 100; todos los checks fallando al 100 % = 0); score por categoría y global expuestos en `/issues/summary`.
- **D.2 · Priorización** — CA: `/issues` ordenado por `priority_score` desc por defecto; cada issue incluye `how_to_fix`.

### Épica E — Rendimiento (≈3 d)

- **E.1 · PSI** — CA: con API key configurada, mide la muestra definida en 03 §7; guarda métricas de laboratorio y de campo si existen; errores de PSI (p. ej. URL no pública) se registran sin fallar el crawl; respetando un tope diario configurable; tests con respuestas grabadas (VCR).
- **E.2 · Checks de rendimiento y móvil** — CA: `perf.*` y `mobile.viewport_missing` generados a partir de E.1/C.1.

### Épica F — Informes (≈4 d)

- **F.1 · CSV/XLSX** — CA: exportaciones de 03 §8 se generan en < 60 s para 10k páginas; columnas documentadas; caracteres UTF-8 correctos en Excel (BOM en CSV).
- **F.2 · PDF** — CA: resumen ejecutivo con score, categorías, top-10 issues priorizados y recomendaciones; se genera sin dependencias de red externas.
- **F.3 · Descarga segura** — CA: URL prefirmada de 15 min; solo el dueño del proyecto puede solicitarla.

### Épica G — UI del MVP (≈8 d, en paralelo con B–F)

- **G.1** Formulario de crawl con validaciones y explicación de límites. CA: no permite enviar valores fuera de rango; muestra el aviso de términos para dominios no verificados.
- **G.2** Progreso en vivo. CA: barra de progreso y contadores se actualizan sin recargar.
- **G.3** Resumen de auditoría. CA: score global, por categoría, top issues; navegación a páginas afectadas.
- **G.4** Explorador de páginas. CA: tabla virtualizada (≥50k filas sin bloquear), filtros por status, indexabilidad, profundidad, texto en URL.
- **G.5** Detalle de página. CA: metadatos, headings en árbol, enlaces in/out, schema, issues, rendimiento.
- **G.6** Exportaciones. CA: lanzar y descargar informes.
- **G.7** Accesibilidad básica. CA: navegación por teclado, contraste AA, `axe` sin violaciones serias en E2E.

### Definición de terminado (MVP)

1. Crawl de un sitio real verificado de ~1 000 páginas termina sin errores respetando robots.txt y el rps configurado.
2. El crawl del sitio fixture produce exactamente el conjunto de issues esperado (test de integración "golden").
3. Suite de seguridad SSRF en verde.
4. Exportación CSV/XLSX/PDF descargable.
5. README de setup, despliegue y limitaciones.

**Total MVP estimado: ≈ 47 días-persona** (≈ 9–10 semanas a tiempo completo; el doble a tiempo parcial).

## Post-MVP (resumen de épicas)

| Épica | Historias clave | CA destacados |
|---|---|---|
| H. Render JS (1.1) | Servicio renderer + Smokescreen; comparar HTML crudo vs renderizado | Tests SSRF repetidos contra el renderer; `ai.content_requires_js` |
| I. Search Console | OAuth, sync diario incremental, rendimiento, striking distance, URL Inspection (cuota 2 000/día/propiedad) | Tokens cifrados; re-sync idempotente; priorización de issues usa impresiones |
| J. GA4 | Tráfico por landing, referrers de IA | Lista de referrers de IA mantenida en config |
| K. Recrawls y diff | Programación, comparación de crawls, alertas email | Diff correcto con fixtures A/B |
| L. Keywords | Proveedor configurable, caché 30 d, listas, clusters, KD propio | Fuente y fecha visibles; presupuesto respetado |
| M. Rank tracking | GSC + SERP API, visibilidad, alertas | Frecuencia configurable; series separadas por fuente |
| N. Competidores / Keyword gap | Descubrimiento, gap de 5 dominios | Reglas de categorías testeadas |
| O. On-page | Recomendaciones URL+keyword vs top-10 | Cada recomendación con evidencia |
| P. GEO | Prompts multi-LLM, menciones, citas, sentimiento | Corte duro por presupuesto; respuestas auditables |
| Q. Backlinks | Import GSC CSV, BWT API, autoridad Common Crawl, proveedor opcional | Import idempotente; métrica etiquetada como estimación |
