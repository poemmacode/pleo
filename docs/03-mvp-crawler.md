# Fase 3 — Plan del MVP: crawler de SEO técnico

El MVP es **solo** el módulo de auditoría técnica (más la base: proyectos, dominios, auth). No depende de ninguna API de pago. La única API externa es PageSpeed Insights (gratuita con API key).

## 1. Alcance del MVP

Incluido:
1. Descubrimiento de URLs desde sitemaps (robots.txt, `/sitemap.xml`, índices, `.gz`) y enlaces internos.
2. Límites configurables: páginas, profundidad, req/s, include/exclude, tamaño máximo de respuesta.
3. Monitoreo de status HTTP y cadenas de redirección.
4. Análisis de title y meta description.
5. Canonical y directivas robots (robots.txt, meta robots, X-Robots-Tag).
6. Jerarquía de headings.
7. Enlaces internos, externos y rotos.
8. Detección de metadatos y contenido duplicados.
9. Extracción y validación de datos estructurados (JSON-LD, Microdata, RDFa).
10. Rendimiento y móvil con PageSpeed Insights API (+ CrUX para datos de campo).
11. Puntuación de salud, priorización e informes exportables (CSV, XLSX, PDF).
12. Seguridad: robots.txt, términos, presupuesto de crawl, protección SSRF/DNS rebinding.

Excluido del MVP (fase posterior): render JS con Playwright (diseñado aquí, se implementa en la iteración 1.1), GSC, programación de recrawls, comparación de crawls.

## 2. Flujo del crawl

```mermaid
sequenceDiagram
  participant U as Usuario
  participant API as Rails API
  participant Q as Sidekiq
  participant H as SafeHttp
  participant W as Sitio
  U->>API: POST /crawls (config)
  API->>API: valida config + dominio verificado + SafeHttp.preflight(start_url)
  API->>Q: StartCrawlJob
  Q->>H: GET /robots.txt
  H->>W: (IP validada y fijada)
  Q->>Q: parse robots, crawl-delay, Sitemap:
  Q->>Q: SitemapDiscoveryJob → crawl_urls(source=sitemap)
  Q->>Q: seed start_url → crawl_urls(source=seed)
  loop mientras haya pending y no se alcance max_pages
    Q->>Q: FetchPageJob(url) — token bucket por host
    Q->>H: GET url (sin seguir redirects automáticamente)
    H->>W: request
    W-->>H: respuesta (≤ max_bytes)
    Q->>Q: parse (Nokogiri) → pages, links, structured_data
    Q->>Q: encola enlaces internos en scope (dedupe por url_hash)
    Q->>Q: RunChecksJob(page) — checks por página
  end
  Q->>Q: FinalizeCrawlJob: checks de sitio (duplicados, huérfanas, broken links, PageRank interno)
  Q->>Q: PSI sobre muestra de URLs
  Q->>Q: ScoreJob → health_score, priority_score
  API-->>U: GET /crawls/:id (status=completed)
```

### Detalles

- **Normalización de URL**: esquema y host en minúsculas, quitar puerto por defecto, quitar fragmento, resolver `.`/`..`, ordenar query params (opcional), eliminar params de tracking configurables (`utm_*`, `gclid`, `fbclid`), IDN → punycode. `url_hash = sha256(url_normalizada)`.
- **Scope**: `domain` (host y subdominios del dominio registrable — vía Public Suffix List), `subdomain` (host exacto), `subfolder` (host + prefijo de path).
- **Frontera**: tabla `crawl_urls` con estado; el `FinalizeCrawlJob` se dispara cuando no quedan `pending/fetching` (contador en Redis + verificación SQL).
- **Redirecciones**: se siguen manualmente (máx. 10), revalidando cada salto con SafeHttp; se guarda `redirect_chain`. Destinos fuera de scope se registran pero no se rastrean.
- **Tipos de contenido**: HTML se parsea; PDFs/imágenes solo HEAD/estado (para enlaces rotos). `max_page_bytes` por defecto 5 MB; se corta la lectura del socket al superarlo.
- **Reintentos**: 429/503 → respetar `Retry-After`, backoff exponencial, máx. 3. Si >20 % de respuestas son 429/5xx en una ventana de 1 min, el crawl **reduce a la mitad** la velocidad automáticamente; si persiste, se pausa (`status=paused`, motivo `server_overloaded`).
- **Timeouts**: connect 5 s, read 15 s, total 30 s por petición.

## 3. Seguridad del crawler

### 3.1 Política de crawl responsable

| Regla | Implementación |
|---|---|
| robots.txt | Parser propio conforme a **RFC 9309** (agrupación por UA, `Allow`/`Disallow` con longest-match, `*` y `$`). Si robots.txt devuelve 5xx o timeout → no se rastrea (se trata como "disallow all") y se informa. 4xx → se permite todo, como dice la RFC. Cache de robots ≤ 24 h. **No es desactivable.** |
| Crawl-delay | Si está presente, `rps_efectivo = min(rps_config, 1/crawl_delay)`. |
| User-Agent | Identificable: `SEOPlatformBot/0.1 (+https://<dominio-propio>/bot; uso personal)`. Se evalúa robots.txt con el token `SEOPlatformBot` y con `*`. En modo "móvil" el UA añade un token móvil, pero el token del bot se mantiene. Nunca se suplanta Googlebot. |
| Dominios verificados | Crawl completo solo de dominios con propiedad verificada (DNS TXT, archivo HTML, meta tag o propiedad GSC). Dominios no verificados (competidores, top-10 de SERP): máx. 200 páginas, 0,5 req/s, sin render JS. |
| Presupuesto | Límites duros globales: máx. 50 000 páginas/crawl, 10 req/s, 2 crawls concurrentes por usuario, 1 crawl activo por host. |
| Términos del sitio | Checkbox obligatorio al crear un crawl de dominio no verificado ("he revisado que los términos del sitio permiten este acceso"). No se usan proxies rotativos, no se resuelven CAPTCHAs, no se evaden bloqueos: un 403/CAPTCHA detectado se registra como tal y se **detiene** el crawl de ese host. |
| `noindex`/`nofollow` | Se respetan para la *decisión de seguir enlaces* solo si el usuario lo elige (por defecto un auditor sí sigue `nofollow` internos para detectarlos; configurable). |

### 3.2 Protección SSRF

Todas las peticiones salientes (crawler, sitemaps, robots, futuras funciones de "probar URL") pasan por `SafeHttp`. Pasos por petición y **por cada salto de redirección**:

1. **Parseo estricto** con `Addressable::URI`: solo `http`/`https`; rechazar userinfo (`user:pass@`), hosts vacíos, caracteres de control y espacios.
2. **Puertos**: solo 80 y 443 (lista configurable por admin, nunca por usuario final).
3. **Host literal IP**: normalizar con `IPAddr` (detecta formas decimal `2130706433`, octal `0177.0.0.1`, hex `0x7f.1`, IPv4-mapeada `::ffff:127.0.0.1`, NAT64 `64:ff9b::/96`) y aplicar la lista de bloqueo.
4. **Resolución DNS propia** (`Resolv::DNS`, timeout 3 s), obteniendo **todas** las A y AAAA. Si **alguna** está en la lista de bloqueo → rechazar (evita respuestas mixtas).
5. **Lista de bloqueo** (IPv4/IPv6):
   - `0.0.0.0/8`, `10.0.0.0/8`, `100.64.0.0/10` (CGNAT), `127.0.0.0/8`, `169.254.0.0/16` (incluye `169.254.169.254`, metadatos AWS/GCP/Azure, y `169.254.170.2` de ECS), `172.16.0.0/12`, `192.0.0.0/24`, `192.0.2.0/24`, `192.88.99.0/24`, `192.168.0.0/16`, `198.18.0.0/15`, `198.51.100.0/24`, `203.0.113.0/24`, `224.0.0.0/4`, `240.0.0.0/4`, `255.255.255.255/32`.
   - `::/128`, `::1/128`, `::ffff:0:0/96` (se re-evalúa la IPv4 embebida), `64:ff9b::/96`, `100::/64`, `2001:db8::/32`, `fc00::/7` (incluye `fd00:ec2::254`, metadatos IPv6 de EC2), `fe80::/10`, `ff00::/8`.
   - Hostnames: `localhost`, `*.localhost`, `*.local`, `*.internal`, `metadata`, `metadata.google.internal`, `instance-data`, y los nombres de servicio internos del despliegue (`postgres`, `redis`, `renderer`…).
6. **Fijar la IP (anti DNS rebinding)**: la conexión TCP se abre **a la IP ya validada**, no al hostname; se envía `Host:` original y SNI con el hostname para TLS, y se verifica el certificado contra el hostname. Así un segundo lookup malicioso con TTL 0 no tiene efecto.
7. **Sin proxies de entorno** (`HTTP_PROXY` ignorado) y sin seguir redirects automáticamente (los maneja el paso de redirección, que repite 1–6).
8. **Límites**: tamaño de respuesta, tiempo total, nº de redirecciones, descompresión limitada (protección contra *zip bombs*: ratio máx. 100:1 y tope absoluto).
9. **Registro**: todo rechazo se guarda como `skip_reason=unsafe_host` con la IP resuelta, para auditoría.

**Defensa en profundidad (infraestructura)**: IMDSv2 obligatorio con hop limit 1; security group / NACL del worker y del renderer que **deniega egress** a `10/8`, `172.16/12`, `192.168/16`, `169.254/16` y a la subred de datos; el renderer sale a internet solo por **Smokescreen**, que aplica la misma política al hacer el CONNECT (resuelve y valida la IP en el momento de conectar).

**Renderer (Playwright, iteración 1.1)**: contenedor sin credenciales AWS, sin acceso a Postgres/Redis, Chromium con `--proxy-server=smokescreen`, `page.route('**/*')` que aborta esquemas no http(s) y `file:`/`data:` de nivel superior, timeouts, un contexto por página, sin descargas, y bloqueo de WebSockets/WebRTC (`--force-webrtc-ip-handling-policy=disable_non_proxied_udp`).

### 3.3 Tests de seguridad obligatorios (RSpec)

Tabla de casos que deben **rechazarse**: `http://127.0.0.1`, `http://2130706433`, `http://0177.0.0.1`, `http://0x7f.0.0.1`, `http://[::1]`, `http://[::ffff:127.0.0.1]`, `http://169.254.169.254/latest/meta-data/`, `http://[fd00:ec2::254]`, `http://metadata.google.internal`, `http://localhost.`, `http://foo.localhost`, `http://user:pass@example.com`, `gopher://`, `file:///etc/passwd`, `http://example.com:6379`, un host cuyo DNS devuelve una IP pública y otra privada, un redirect 302 de un sitio público a `http://10.0.0.1`, y un **rebinding** simulado (resolver stub que devuelve IP pública en el primer lookup y `127.0.0.1` en el segundo: la petición debe ir a la IP pública validada).

## 4. Extracción por página

| Campo | Fuente |
|---|---|
| status, headers, tiempos, redirect chain | respuesta HTTP |
| title, meta description, meta robots, canonical, hreflang, lang, viewport, charset, OG/Twitter | `<head>` |
| X-Robots-Tag, Link: rel=canonical | headers |
| headings H1–H6 en orden | DOM |
| enlaces (`a[href]`, `link[href]`, `img[src]`, `script[src]`), anchor, `rel` | DOM, resueltos contra `<base>` |
| texto visible, word count, simhash 64-bit | DOM sin script/style/nav (heurística) |
| datos estructurados | `script[type="application/ld+json"]`, `itemscope/itemprop`, `typeof/property` |
| imágenes sin `alt`, tamaño | DOM |
| mixed content | recursos `http:` en página `https:` |

## 5. Catálogo de checks del MVP (propio)

Severidad: **E** error, **W** warning, **N** notice. Peso 1–10 (usado en score y prioridad).

| Categoría | Key | Sev | Peso | Regla |
|---|---|---|---|---|
| Rastreabilidad | `http.4xx` | E | 9 | página interna enlazada con 4xx |
| | `http.5xx` | E | 10 | 5xx |
| | `http.timeout` | E | 7 | sin respuesta en el tiempo límite |
| | `redirect.chain` | W | 4 | >1 salto |
| | `redirect.loop` | E | 8 | bucle |
| | `redirect.temporary` | N | 2 | 302/307 en enlaces internos |
| | `robots.blocked_internal_linked` | W | 4 | URL enlazada internamente pero bloqueada por robots.txt |
| | `sitemap.non_200` | W | 5 | URL del sitemap que no da 200 |
| | `sitemap.noindex` | W | 5 | URL del sitemap no indexable |
| | `sitemap.missing` | W | 3 | no hay sitemap descubrible |
| | `page.orphan` | W | 4 | en sitemap pero sin enlaces internos entrantes |
| | `page.deep` | N | 2 | profundidad > 4 clics |
| Indexabilidad | `robots.noindex` | N | 1 | noindex (informativo; se marca W si está en sitemap) |
| | `canonical.missing` | N | 2 | sin canonical |
| | `canonical.to_non200` | E | 7 | canonical apunta a 3xx/4xx/5xx |
| | `canonical.to_noindex` | E | 7 | canonical apunta a página noindex |
| | `canonical.multiple` | E | 6 | más de un canonical (head + header incluidos) en conflicto |
| | `canonical.relative_or_invalid` | W | 3 | canonical inválido o relativo |
| | `canonical.chain` | W | 4 | canonical → página con otro canonical |
| | `hreflang.no_return` | W | 4 | falta enlace recíproco |
| | `hreflang.invalid_code` | W | 4 | código ISO inválido |
| Metadatos | `title.missing` | E | 8 | sin title o vacío |
| | `title.duplicate` | E | 6 | mismo title en ≥2 páginas indexables |
| | `title.too_long` | W | 2 | > 60 caracteres (aprox. ~580 px) |
| | `title.too_short` | N | 1 | < 15 caracteres |
| | `title.multiple` | W | 3 | más de un `<title>` |
| | `meta_description.missing` | W | 3 | sin meta description |
| | `meta_description.duplicate` | W | 4 | duplicada entre páginas indexables |
| | `meta_description.length` | N | 1 | <70 o >160 caracteres |
| Contenido | `h1.missing` | W | 4 | sin H1 |
| | `h1.multiple` | N | 1 | varios H1 |
| | `headings.skipped_level` | N | 1 | salto de nivel (H2 → H4) |
| | `h1.equals_title` | N | 1 | informativo |
| | `content.thin` | W | 3 | < 200 palabras en página indexable (umbral configurable) |
| | `content.duplicate` | W | 5 | simhash con distancia de Hamming ≤ 3 entre páginas indexables |
| | `images.missing_alt` | W | 2 | imágenes sin `alt` |
| Enlaces | `links.internal_broken` | E | 9 | enlace interno a 4xx/5xx |
| | `links.external_broken` | W | 3 | enlace externo roto (verificación con HEAD, limitada a 1 por host/s) |
| | `links.internal_nofollow` | W | 3 | `nofollow` en enlace interno |
| | `links.to_redirect` | N | 2 | enlace interno a URL que redirige |
| | `links.too_many` | N | 1 | > 300 enlaces en la página |
| Datos estructurados | `schema.invalid_json` | E | 6 | JSON-LD no parseable |
| | `schema.unknown_type` | W | 3 | `@type` no existe en el vocabulario schema.org |
| | `schema.missing_required` | W | 4 | faltan propiedades requeridas para resultados enriquecidos (reglas propias derivadas de la documentación pública de Google Search Central: Article, Product, BreadcrumbList, FAQPage, Organization, LocalBusiness, Event, Recipe…) |
| | `schema.none` | N | 1 | página sin datos estructurados |
| HTTPS | `https.not_used` | E | 8 | página servida por http |
| | `https.mixed_content` | W | 5 | recursos http en página https |
| | `https.http_links` | N | 2 | enlaces internos a versión http |
| | `https.cert_invalid` | E | 9 | certificado inválido/expirado |
| Móvil | `mobile.viewport_missing` | W | 5 | sin meta viewport |
| Rendimiento | `perf.lcp_poor` | W | 5 | LCP > 4 s (PSI) |
| | `perf.cls_poor` | W | 4 | CLS > 0,25 |
| | `perf.inp_poor` | W | 4 | INP > 500 ms (CrUX, si existe) |
| | `perf.score_low` | N | 2 | score Lighthouse < 50 |
| | `perf.slow_ttfb` | N | 2 | TTFB del crawler > 1,5 s |
| | `page.too_large` | N | 2 | HTML > 2 MB |
| GEO / AI search | `ai.bots_blocked` | W | 3 | robots.txt bloquea bots de IA relevantes (lista mantenida en config, informativo: puede ser intencional) |
| | `ai.llms_txt_missing` | N | 1 | sin `/llms.txt` (estándar propuesto, impacto no garantizado) |
| | `ai.content_requires_js` | W | 4 | (con render JS) texto visible renderizado ≫ texto en HTML crudo |

Los textos de "cómo arreglarlo" se redactan desde cero en español; no se copian descripciones de terceros.

## 6. Puntuación y priorización (fórmulas propias)

**Health score (0–100)**, por categoría y global:

```
penalización(check) = peso(check) × min(1, páginas_afectadas / páginas_indexables_rastreadas) ^ 0.5
score_categoria    = 100 × (1 − Σ penalización / Σ peso_de_checks_aplicables)
health_score       = media ponderada de categorías (rastreabilidad 25, indexabilidad 20, enlaces 15,
                     metadatos 15, contenido 10, https 5, schema 5, rendimiento 5)
```
La raíz cuadrada evita que un issue en el 1 % de páginas sea irrelevante y que uno en el 100 % sea lineal. Los notices pesan pero no bajan más de 5 puntos en total.

**Prioridad de un issue (0–100)**:
```
priority = 10 × peso(check) × (0.5 × cobertura + 0.5 × importancia_media_páginas)
importancia_página = normalizado(PageRank interno)          # MVP
                   → 0.5 × PageRank + 0.5 × impresiones GSC  # cuando haya GSC
```

## 7. Rendimiento con PageSpeed Insights

- Muestra: home + top-N URLs por PageRank interno (por defecto 20), una por plantilla de URL detectada (agrupación por patrón de path), `strategy=mobile` y opcionalmente `desktop`.
- Llamada: `GET https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=…&strategy=mobile&category=performance&category=seo&category=accessibility&key=…`. Se guardan LCP, CLS, TBT, FCP, TTFB, score y oportunidades; si la respuesta incluye `loadingExperience` (CrUX), también INP/LCP/CLS de campo (p75).
- Rate limit interno: 1 req/s y máx. diario configurable (la cuota gratuita es amplia; ver 05).
- PSI ejecuta Lighthouse en servidores de Google contra la URL pública → no hay riesgo SSRF propio, pero solo funciona con URLs públicas.

## 8. Informes exportables

- **CSV**: páginas (todas las columnas), issues (check × URL), enlaces rotos, duplicados.
- **XLSX** (`caxlsx`): pestañas Resumen, Issues priorizados, Páginas, Enlaces rotos, Duplicados, Schema, Rendimiento.
- **PDF** (HTML → PDF con Grover/Playwright en el renderer, o `prawn`): resumen ejecutivo con health score, top-10 issues por prioridad con explicación y "cómo arreglarlo", gráficos por categoría, y comparación con el crawl anterior si existe.
- Generación asíncrona; descarga por URL prefirmada de corta duración.

## 9. Frontend del MVP

Pantallas: Login · Proyectos · Dominio (verificación) · Nuevo crawl (formulario con límites) · Progreso del crawl (polling cada 3 s) · Resumen de auditoría (score, categorías, top issues) · Lista de issues → páginas afectadas · Explorador de páginas (tabla filtrable) · Detalle de página · Duplicados · Rendimiento · Exportaciones.

## 10. Estrategia de pruebas

| Nivel | Herramientas | Qué cubre |
|---|---|---|
| Unitarias | RSpec | SafeHttp (tabla SSRF), parser robots.txt (casos de la RFC 9309), normalización de URL, cada check con HTML fixture, simhash, fórmulas de score |
| Integración | RSpec + **sitio fixture local** (Rack app con páginas, redirects, 404, sitemap, robots) + WebMock para PSI | Crawl completo de punta a punta → issues esperados exactos |
| Request specs | RSpec + rswag | Contratos API y OpenAPI generado |
| Frontend | Vitest + Testing Library + MSW | Componentes y hooks con API mockeada |
| E2E | Playwright Test | Crear proyecto → crawl del sitio fixture → ver issues → exportar CSV |
| Seguridad | RSpec + `brakeman` + `bundler-audit` + `npm audit` en CI | |

Nota: el sitio fixture corre en localhost, lo que SafeHttp bloquea. En `test` se inyecta un resolver/allowlist explícito solo para el host del fixture; esta excepción no existe en ningún otro entorno (verificado por un spec).
