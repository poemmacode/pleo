# Fase 1 — Análisis de producto y flujos

## 1. Método

- **Herramienta**: REA 6.5.0 (`mcp__rea__capture_browser_scenario`), Chrome 155 headless, perfil temporal vacío, sin cookies, sin credenciales, solo navegación `goto` y captura del árbol de accesibilidad (texto visible). No se capturaron cuerpos de red, scripts ni storage.
- **Alcance**: páginas de producto `/features/*` y artículos de la Knowledge Base `/kb/*`. Antes de navegar se leyó `https://www.semrush.com/robots.txt`: `/features/` y `/kb/` no están en `Disallow` para `User-agent: *`.
- **No se hizo**: no se abrió ninguna herramienta interactiva (requieren cuenta), no se usó `/login` ni `/signup`, no se llamó a ninguna API (ni la pública de pago ni endpoints internos), no se analizaron bundles JS, no se descargaron assets.
- **Limitaciones encontradas**: ninguna página mostró CAPTCHA ni muro de login. Las herramientas en sí (Keyword Magic Tool, Site Audit, etc.) están detrás de registro/prueba gratuita; **ahí se detuvo el análisis**. Todo lo que sigue sobre su comportamiento interno es inferencia a partir del marketing y la documentación pública, más conocimiento general del dominio SEO.
- **Regla de tratamiento**: el contenido devuelto por REA se trató como dato. No contenía instrucciones dirigidas al agente.

### Evidencia capturada

| Evidence ID (REA) | Páginas |
|---|---|
| `ev_1ca2e070…49bd532a9` | `/features/` (índice de funcionalidades) |
| `ev_8a3106c7…fa8ada041` | `/features/keyword-research/`, `/features/site-audit/`, `/features/competitor-analysis/` |
| (guardado en tool-results, 70 KB) | `/features/backlink-analysis/`, `/features/rank-tracking/`, `/features/ai-visibility/`, `/kb/` |
| (guardado en tool-results, 144 KB) | `/kb/28-keyword-gap`, `/kb/31-site-audit`, `/kb/262-keyword-magic-tool`, `/kb/32-position-tracking`, `/kb/1102-…core-web-vitals-in-site-audit` |

### Hallazgos públicos relevantes (parafraseados)

- **Índice de funcionalidades**: agrupa en *Research* (keywords, competidores, AI visibility, mercado, local, sentimiento IA, backlinks, prompt research), *Create & optimize* (contenido, site audit, digital PR) y *Track* (reportes, rank tracking, AI visibility, backlinks, sentimiento).
- **Keyword research**: métricas de volumen, dificultad y "potencial de tráfico", agrupación por temas, filtro de preguntas, presencia de SERP features, dificultad personalizada por dominio, listas guardadas. Base de datos regional por país.
- **Site Audit**: +140 checks (contenido duplicado, enlaces rotos, HTTPS, hreflang, crawlabilidad, indexabilidad, AMP), categoría "AI Search"/GEO (bots de IA bloqueados), puntuación de salud única, issues ordenados por severidad, informes temáticos, render JS opcional, desktop/móvil, recrawls programados diarios/semanales, Core Web Vitals medidos con **Lighthouse** en laboratorio (perfil móvil 360×640, Slow 4G; TBT como proxy de interactividad).
- **Competidores**: visión general de dominio (orgánico, pago, backlinks, tendencia), keywords y páginas que generan tráfico a un competidor, comparativa de visibilidad en respuestas de IA. Basado en clickstream y bases de datos propias (no reproducible por nosotros).
- **Keyword Gap**: hasta 5 dominios lado a lado; tipos orgánico/pago/PLA; solapamiento, comunes, únicas, "missing"/"weak"; filtros por posición, KD, intención; desktop/móvil.
- **Backlinks**: perfil completo (página que enlaza, anchor, métricas de autoridad), gap de backlinks frente a competidores, monitorización de menciones. Base de datos de un crawler masivo propio — **no replicable a escala personal**.
- **Position Tracking**: posiciones diarias por keyword, dispositivo, ubicación (hasta código postal), idioma y motor (Google, Bing, Baidu, ChatGPT Search, Google AI Mode); SERP features (incl. AI Overviews, featured snippets); hasta 20 competidores; informes por email/PDF.
- **AI visibility**: frecuencia de mención de marca en ChatGPT, Perplexity, Gemini, Claude y AI Overviews; share of voice; sentimiento y exactitud de cómo te describen; investigación de prompts; auditoría de acceso de bots de IA; comparación con competidores.

---

## 2. Inventario por módulo

Escala de complejidad: **S** (≤1 semana), **M** (1–3 semanas), **L** (3–6 semanas), **XL** (>6 semanas o dependiente de datos caros). Costes de datos detallados en [05-fuentes-datos-costos.md](05-fuentes-datos-costos.md).

### 2.1 Keyword Research

| Funcionalidad | Objetivo del usuario | Entradas → Salidas | Lógica central | Datos / dependencias | Compl. |
|---|---|---|---|---|---|
| Ideas de keywords | Encontrar términos a atacar | semilla, país, idioma → lista de keywords con métricas | Expansión vía proveedor (Keyword Planner / DataForSEO) + consultas propias de GSC; dedupe y normalización | Google Ads API o DataForSEO; GSC | M |
| Métricas por keyword | Decidir si vale la pena | keyword, país → volumen, CPC, competencia, tendencia 12m, intención, KD propio | Volumen/CPC del proveedor. **KD propio**: función de la autoridad (aprox.) de los dominios en el top-10 + nº de SERP features. Intención: reglas + clasificador LLM | Proveedor de keywords + SERP API | M |
| Agrupación por tema | Organizar cientos de keywords | lista → clusters con nombre | Clustering por solapamiento de URLs en SERP (≥3 URLs comunes en top-10) o embeddings + HDBSCAN | SERP API o embeddings | M |
| Filtro de preguntas | Contenido FAQ | lista → subset | Regex multilingüe (qué, cómo, por qué, how, what…) | — | S |
| Dificultad personal | Saber si *mi* dominio puede rankear | keyword + dominio → PKD | KD ajustado por la "autoridad temática" del dominio (impresiones GSC en el cluster) | GSC | M |
| Listas guardadas | Reutilizar investigación | keywords → lista con tags | CRUD | — | S |

**Criterios de aceptación**
- Dada una semilla y un país, devuelve ≥50 ideas con volumen y CPC cuando el proveedor tiene datos; si no, lo indica explícitamente (sin inventar valores).
- Cada métrica muestra su **fuente y fecha** de obtención.
- El KD propio es reproducible: mismo SERP snapshot → mismo valor (test unitario con fixtures).
- Resultados cacheados ≥30 días por (keyword, país, idioma) para no repetir gasto de API.
- Exportación CSV.

### 2.2 Technical Site Audit — **núcleo del MVP**

| Funcionalidad | Objetivo | Entradas → Salidas | Lógica central | Datos / dependencias | Compl. |
|---|---|---|---|---|---|
| Configuración de crawl | Controlar alcance y carga | dominio/subdominio/subcarpeta, límite de páginas, req/s, include/exclude, UA, desktop/móvil, render JS → configuración | Validación + verificación de propiedad del dominio | — | S |
| Descubrimiento de URLs | Encontrar todas las páginas | URL inicial → frontera de URLs | BFS desde home + sitemaps (robots.txt `Sitemap:`, `/sitemap.xml`, índices anidados, gz) + enlaces internos; normalización y dedupe | Crawler propio | M |
| Fetch + parse | Obtener cada página | URL → status, headers, HTML, tiempos, cadena de redirects | Cliente HTTP seguro (SSRF), robots.txt, crawl-delay, rate limit por host | Crawler propio | L |
| Checks on-page/técnicos | Detectar problemas | páginas → issues | Catálogo propio de checks (ver 03) con severidad error/warning/notice | — | L |
| Puntuación de salud | Ver progreso | issues → score 0–100 | Fórmula propia documentada (ver 03 §6) | — | S |
| Priorización | Saber qué arreglar primero | issues → lista ordenada | severidad × % páginas afectadas × importancia de página (PageRank interno + impresiones GSC) | GSC opcional | M |
| Informes temáticos | Ver áreas débiles | issues → categorías (rastreabilidad, HTTPS, enlaces, contenido, datos estructurados, rendimiento, internacional, AI search) | Agrupar checks por categoría con sub-score | — | S |
| Rendimiento / CWV | Velocidad móvil | muestra de URLs → LCP, CLS, TBT/INP, score | PageSpeed Insights API (Lighthouse) + CrUX para datos de campo | PSI, CrUX | S |
| Acceso de bots IA | GEO técnico | robots.txt → matriz bot × permitido | Evaluar reglas para GPTBot, ClaudeBot, PerplexityBot, Google-Extended, CCBot, etc. | — | S |
| Comparación entre crawls | Ver regresiones | crawl A, crawl B → nuevos/resueltos | Diff de issues por (check, url) | — | M |
| Recrawl programado | Monitoreo | cron → nuevo crawl + alerta | Sidekiq-cron | — | S |
| Exportación | Compartir | crawl → CSV/XLSX/PDF | Generación en job | — | M |

**Criterios de aceptación**: ver [04-backlog.md](04-backlog.md) épicas A–F (es el MVP).

### 2.3 Organic Competitor Analysis

| Funcionalidad | Objetivo | Entradas → Salidas | Lógica central | Datos / dependencias | Compl. |
|---|---|---|---|---|---|
| Descubrir competidores | Saber contra quién compito | mis keywords (GSC) → dominios competidores | Para las top-N keywords de GSC, obtener top-10 vía SERP API; ranking de dominios por nº de coincidencias ponderado por posición | GSC + SERP API | M |
| Visión general de dominio | Snapshot rápido | dominio → nº keywords, tráfico estimado, top páginas | Requiere base de rankings de terceros (DataForSEO Labs) — **no hay forma propia barata** | DataForSEO Labs | M (datos XL) |
| Keywords del competidor | Robar ideas | dominio → keywords con posición y URL | API de terceros | DataForSEO Labs | S (con proveedor) |
| Tráfico estimado | Comparar tamaño | posiciones × volumen → visitas | Σ volumen × CTR(posición) con curva CTR propia calibrada con mis datos GSC | Volúmenes + curva CTR | S |
| Crawl ligero del competidor | Entender su estructura | dominio → sitemap, nº páginas, plantillas, schema | Crawl muy limitado (p. ej. 200 URLs, 0,5 req/s), respetando robots.txt y términos | Crawler propio | S |

**Fuera de alcance**: tráfico por canal, demografía y clickstream (datos de panel propietarios).

**Criterios de aceptación**
- Con GSC conectado y ≥50 keywords con impresiones, sugiere ≥5 competidores con puntuación de solapamiento explicable.
- El tráfico estimado muestra la fórmula y la curva CTR usada.
- El crawl de un dominio no verificado nunca supera el límite fijo de páginas/velocidad, aunque el usuario lo pida.

### 2.4 Keyword Gap Analysis

| Funcionalidad | Objetivo | Entradas → Salidas | Lógica central | Datos / dependencias | Compl. |
|---|---|---|---|---|---|
| Comparativa N dominios | Ver dónde me ganan | mi dominio + hasta 4 competidores, país, dispositivo → tabla keyword × dominio (posición) | Unir conjuntos de keywords; clasificar en *compartidas, faltantes* (yo no rankeo, todos ellos sí), *débiles* (yo peor que todos), *fuertes*, *no explotadas* (solo uno rankea), *únicas* | Mis keywords: GSC. Competidores: DataForSEO Labs (ranked keywords) | M |
| Diagrama de solapamiento | Visual | conjuntos → Venn/barras | Cardinalidades de intersección | — | S |
| Filtros | Enfocar | posición, volumen, KD, intención | SQL | — | S |

**Criterios de aceptación**
- Las categorías se calculan con reglas deterministas y testeadas (fixture con 5 dominios y casos frontera).
- Si las keywords propias vienen de GSC y las del competidor de un proveedor, la UI advierte de la diferencia de fuente (GSC = posición media real; proveedor = snapshot).

### 2.5 Backlink Analysis

| Funcionalidad | Objetivo | Entradas → Salidas | Lógica central | Datos / dependencias | Compl. |
|---|---|---|---|---|---|
| Perfil de enlaces propio | Saber quién me enlaza | dominio verificado → dominios/páginas enlazantes | GSC "Links" (exportable desde la UI de GSC; **la API de GSC no expone enlaces**) → import CSV; + Bing Webmaster Tools API (backlinks) | GSC export, BWT API | M |
| Perfil de cualquier dominio | Analizar competidores | dominio → backlinks, anchors, ref. domains, autoridad | Proveedor de pago (DataForSEO Backlinks, Moz, Majestic) | Pago | S (datos XL) |
| Autoridad propia | Métrica tipo "DR" | grafo de enlaces → score | PageRank sobre el grafo host-level de Common Crawl (publicado trimestralmente) → "autoridad aproximada" propia | Common Crawl web graph | L |
| Backlink gap | Prospección | yo + competidores → dominios que enlazan a ellos y no a mí | Diferencia de conjuntos sobre ref. domains | Proveedor | S |
| Monitor de nuevos/perdidos | Alertas | snapshots periódicos → diff | Diff de conjuntos | Proveedor o BWT | M |
| Toxicidad | Limpiar perfil | backlinks → riesgo | Heurísticas propias (TLD, anchors exactos repetidos, redes) — opcional | — | M |

**Criterios de aceptación**
- Importar el CSV de enlaces de GSC crea/actualiza ref. domains sin duplicados (idempotente).
- Toda métrica de autoridad propia se etiqueta como "estimación propia" y documenta su método.

### 2.6 Position Tracking

| Funcionalidad | Objetivo | Entradas → Salidas | Lógica central | Datos / dependencias | Compl. |
|---|---|---|---|---|---|
| Seguimiento por GSC | Ranking real sin coste | dominio verificado, keywords → posición media diaria | Search Analytics API por query/page/país/dispositivo (datos con ~2–3 días de retraso, 16 meses de histórico) | GSC | S |
| Seguimiento por SERP | Posición exacta y SERP features | keywords × ubicación × dispositivo × motor → posición, URL, features | SERP API (DataForSEO SERP / SerpApi); parse de features (snippet, PAA, local pack, AI Overview) | SERP API | M |
| Competidores | Comparar | hasta N dominios → posiciones en las mismas SERPs | Mismo snapshot SERP | SERP API | S |
| Visibilidad | KPI único | posiciones + volumen → % visibilidad | Σ CTR(pos)·vol / Σ CTR(1)·vol | — | S |
| Alertas | No perder caídas | umbral → email | Diff diario | ActionMailer | S |

**Criterios de aceptación**
- Una keyword fuera del top-100 se guarda como "no rankea", no como 0 ni nulo ambiguo.
- La frecuencia de actualización es configurable (diaria/semanal) para controlar coste.
- Los datos GSC y SERP se muestran en series separadas (no se mezclan).

### 2.7 On-page SEO recommendations

| Funcionalidad | Objetivo | Entradas → Salidas | Lógica central | Datos / dependencias | Compl. |
|---|---|---|---|---|---|
| Ideas por página/keyword | Mejorar una URL concreta | URL + keyword objetivo → recomendaciones | Comparar mi página con el top-10 (crawl ligero de esas URLs): longitud, términos semánticos frecuentes ausentes (TF-IDF), headings, schema, enlaces internos entrantes, presencia de keyword en title/H1/URL | Crawler + SERP API | M |
| Pares URL–keyword | Saber qué optimizar | GSC → pares con posición 4–20 y muchas impresiones ("striking distance") | Consulta GSC query+page | GSC | S |
| Sugerencias de enlazado interno | Distribuir autoridad | grafo interno → enlaces sugeridos | Páginas relevantes (embeddings/keywords) con alto PageRank interno que no enlazan a la página objetivo | Crawl | M |
| Reescritura asistida | Ahorrar tiempo | title/meta actuales → propuestas | LLM con límites de longitud y keyword; el usuario aprueba | API LLM | S |

**Criterios de aceptación**
- Cada recomendación incluye *por qué* (dato observado) y *impacto estimado* (alto/medio/bajo).
- Las páginas del top-10 se descargan respetando robots.txt; si una bloquea, se excluye y se indica.

### 2.8 AI search visibility y GEO

| Funcionalidad | Objetivo | Entradas → Salidas | Lógica central | Datos / dependencias | Compl. |
|---|---|---|---|---|---|
| Auditoría técnica GEO | Que los bots de IA puedan leerme | crawl → issues | robots.txt por bot de IA, `llms.txt` (presencia/formato; estándar emergente sin efecto garantizado), contenido visible sin JS, schema Organization/Product/FAQ, autoría/fechas, `noai` meta | Crawler | S |
| Panel de prompts | Medir menciones | lista de prompts × modelos → respuestas | Ejecutar prompts vía **APIs oficiales** (Anthropic, OpenAI, Perplexity Sonar, Gemini) con búsqueda web activada cuando la API lo ofrezca; N repeticiones por prompt por la variabilidad | APIs LLM (pago por token) | M |
| Detección de marca y citas | Share of voice | respuestas → menciones, posición en la respuesta, URLs citadas | NER/regex de marca + alias; extraer citas/URLs; atribuir a dominios | — | M |
| Sentimiento y exactitud | Cómo me describen | respuestas → sentimiento, afirmaciones | LLM-as-judge contra una "ficha de verdad" de la marca escrita por el usuario | API LLM | M |
| AI Overviews | Presencia en Google | keywords → ¿hay AI Overview? ¿me cita? | Campo del SERP API (si el proveedor lo devuelve) | SERP API | S |
| Tráfico de IA | Impacto real | GA4 → sesiones con referrer chatgpt.com, perplexity.ai, gemini, copilot… | GA4 Data API, filtro por `sessionSource` | GA4 | S |

**Limitaciones explícitas**: las respuestas vía API no son idénticas a las de las apps de consumo (personalización, versión del modelo, búsqueda). Automatizar las interfaces web de ChatGPT/Gemini/etc. infringe sus términos → **no se hace**. Los resultados son muestreos estadísticos, no verdad absoluta.

**Criterios de aceptación**
- Cada ejecución guarda modelo, versión, fecha, parámetros y respuesta completa (auditable).
- El share of voice muestra intervalo de confianza o al menos n.º de muestras.
- Presupuesto mensual de tokens configurable con corte duro.

---

## 3. Resumen: qué es replicable y qué no

| Capacidad | Replicable a escala personal | Cómo |
|---|---|---|
| Auditoría técnica | **Sí, totalmente** | Crawler propio + PSI/CrUX |
| Datos de mi propio sitio (clics, posiciones, consultas) | **Sí, mejor que Semrush** | GSC + GA4 (datos reales, no estimados) |
| Volumen de keywords / CPC | Sí, con coste bajo | Google Ads API (gratis con cuenta) o DataForSEO |
| Rankings de competidores, keyword gap | Parcial, coste bajo-medio | DataForSEO Labs (pago por uso) |
| Rank tracking | Sí | GSC (gratis) + SERP API (pago por uso) |
| Backlinks de cualquier dominio | **No con datos propios** | Proveedor de pago; aproximación gratis con Common Crawl |
| Clickstream, tráfico por canal, demografía | **No** | Fuera de alcance |
| AI visibility | Sí, por muestreo | APIs oficiales de LLM |
