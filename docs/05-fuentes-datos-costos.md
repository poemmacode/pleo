# Fuentes de datos y costos

> **Aviso**: precios y cuotas son aproximados según la información pública conocida hasta 2026 y **deben verificarse en la página oficial de cada proveedor antes de contratar**. Se marcan con ⚠︎ los valores con más incertidumbre.

## 1. Tabla de fuentes

| Fuente | Módulos | Qué aporta | Acceso / autorización | Cuota / límites | Costo |
|---|---|---|---|---|---|
| **Crawler propio** | Audit, OnPage, Competitors (ligero), GEO técnico | HTML, estados, enlaces, metadatos, schema | Propio; robots.txt + verificación de dominio | Los que fijemos (03 §3.1) | Solo infraestructura |
| **PageSpeed Insights API v5** | Performance | Lighthouse lab (LCP, CLS, TBT…), oportunidades; CrUX embebido | API key de Google Cloud | ≈ 25 000 consultas/día, ≈ 400 por 100 s | **Gratis** |
| **CrUX API** | Performance | Datos de campo p75 (LCP, INP, CLS) por URL/origen, 28 días | API key | ≈ 150 consultas/min | **Gratis** |
| **Google Search Console API** | SearchConsole, RankTracking, OnPage, Competitors | Clics, impresiones, CTR, posición por query/página/país/dispositivo (16 meses); sitemaps; URL Inspection | OAuth (`webmasters.readonly`), solo propiedades del usuario | Search Analytics ≈ 1 200 QPM por sitio; URL Inspection ≈ 2 000/día y 600/min por propiedad | **Gratis** |
| GSC — informe de enlaces | Backlinks | Top dominios/páginas enlazantes | Export CSV manual desde la UI (la API **no** expone enlaces) | Muestra parcial | **Gratis** |
| **GA4 Data API** | Analytics, GEO | Sesiones por fuente/landing; tráfico de referrers de IA | OAuth (`analytics.readonly`) | Cuotas por tokens por propiedad (≈ 200k tokens/día en propiedades estándar ⚠︎) | **Gratis** |
| **Bing Webmaster Tools API** | Backlinks, RankTracking | Enlaces entrantes, consultas y posiciones en Bing | API key de la cuenta BWT, sitio verificado | Límites diarios moderados | **Gratis** |
| **Google Ads API — Keyword Planner** | Keywords | Ideas de keywords, volumen mensual, CPC, competencia, tendencia | Cuenta de Google Ads + cuenta de administrador + *developer token* con acceso Basic (requiere solicitud) | Las cuentas sin gasto activo reciben volúmenes en rangos | **Gratis** (requiere cuenta Ads) |
| **DataForSEO** (pay-as-you-go) | Keywords, Serp, RankTracking, Competitors, Gap | SERP de Google/Bing (incl. AI Overview si existe), volúmenes, *ranked keywords* de cualquier dominio, backlinks | Contrato y API key; licencia para uso de los datos | Depósito mínimo ≈ 50 USD ⚠︎ | SERP cola estándar ≈ 0,0006 USD/consulta, *live* ≈ 0,002 ⚠︎; volúmenes ≈ 0,05 USD por lote de hasta 1 000 keywords ⚠︎; Labs ≈ 0,01 USD/petición + 0,0001/ítem ⚠︎; Backlinks API con compromiso mensual ≈ 100 USD ⚠︎ |
| SerpApi (alternativa SERP) | Serp, RankTracking | SERPs parseadas, muchos motores | API key | Plan gratuito pequeño | Desde ≈ 75 USD/mes por 5 000 búsquedas ⚠︎ |
| **Common Crawl** | Backlinks (autoridad aproximada) | Web graph a nivel host/dominio publicado periódicamente; WARC | Datos abiertos (AWS Open Data) con sus términos de uso | Descarga de varios GB por release | **Gratis** (+ cómputo para PageRank) |
| Moz Links API | Backlinks | DA/PA, enlaces | Suscripción | Por filas/mes | Decenas a cientos de USD/mes ⚠︎ |
| Majestic API | Backlinks | Trust/Citation Flow, enlaces | Suscripción API | — | ≈ 400 USD/mes ⚠︎ |
| Ahrefs API | Backlinks, Keywords | Datos completos | Solo planes Enterprise | — | ≥ 1 000 USD/mes ⚠︎ — **no recomendado** |
| Semrush API | Todos | Datos de Semrush | Plan Business + unidades API | — | Alto ⚠︎ — **excluido** por el objetivo de independencia |
| **Anthropic API** (Claude) | GEO, OnPage (reescritura), clasificación de intención | Respuestas con búsqueda web, juicio de sentimiento | API key | Rate limits por tier | Por token + tarifa de herramienta de búsqueda web; ver tabla vigente |
| OpenAI API | GEO | Respuestas con búsqueda web | API key | Por tier | Por token + búsquedas ⚠︎ |
| Perplexity Sonar API | GEO | Respuestas con citas | API key | — | Por token + tarifa por petición ⚠︎ |
| Gemini API | GEO | Respuestas con *grounding* en Google Search | API key | Cuota gratuita limitada | Por token + grounding ⚠︎ |
| schema.org vocabulario | Audit (schema) | Tipos y propiedades | Descarga pública (CC BY-SA 3.0) | — | **Gratis** |
| Public Suffix List | Crawling (scope) | Dominio registrable | Pública (MPL 2.0) | — | **Gratis** |

### Fuentes descartadas (y por qué)

| Fuente | Motivo |
|---|---|
| Scraping directo de SERPs de Google/Bing | Prohibido por sus términos y protegido por anti-bot |
| Automatizar las apps web de ChatGPT, Gemini, Perplexity, Claude | Prohibido por sus términos; se usan sus APIs oficiales |
| Endpoints internos o API privada de Semrush | Fuera de los límites del proyecto |
| Google Custom Search JSON API | Cerrada a nuevos clientes y con retirada anunciada ⚠︎; además no refleja la SERP real |
| Datos de clickstream / paneles | No hay fuente autorizada asequible |

## 2. Escenarios de costo mensual (uso personal)

Supuestos: 1–3 sitios propios, ~5 000 páginas cada uno, 1 crawl semanal.

| Escenario | Incluye | Datos | Infra | Total aprox. |
|---|---|---|---|---|
| **MVP local** | Crawler + PSI en tu Mac | 0 | 0 | **0 USD** |
| **MVP en la nube** | Lo anterior en 1 EC2/Lightsail con Kamal | 0 | 30–60 | **30–60 USD** |
| + GSC, GA4, BWT, CrUX | Fases 2–3 | 0 | — | **+0** |
| + Keywords (Keyword Planner) | Fase 4 | 0 | — | **+0** |
| + Keywords (DataForSEO) | ~200 consultas de volumen/ideas al mes | 1–5 | — | **+1–5 USD** |
| + Rank tracking SERP | 200 keywords, diario, cola estándar ≈ 6 000 SERPs | ≈ 4 | — | **+≈4 USD** |
| + Competidores / Gap | 20 análisis de dominio/mes en Labs | 2–10 | — | **+2–10 USD** |
| + GEO | 50 prompts × 4 modelos × 3 repeticiones, semanal ≈ 2 400 llamadas | 20–80 ⚠︎ | — | **+20–80 USD** |
| + Backlinks de terceros | DataForSEO Backlinks o Moz | 100–400 | — | **+100–400 USD** (opcional) |

Recomendación: llegar hasta GEO con **< 150 USD/mes** total y decidir backlinks de pago solo si el módulo con Common Crawl + GSC + BWT resulta insuficiente.

## 3. Control de gasto (requisito de diseño)

- Todo proveedor pasa por `Providers::<X>` que registra `api_usage` (unidades, costo estimado, cacheado sí/no).
- Presupuesto mensual por proyecto; al 80 % alerta, al 100 % corte duro (las peticiones devuelven `402 budget_exceeded` en la API interna).
- Caché por clave (keyword+país+idioma, dominio+fecha…) con TTL por tipo: volúmenes 30 d, SERP 1 d, ranked keywords de competidor 7 d.
- Panel `/usage` con gasto por proveedor y proyección de fin de mes.
