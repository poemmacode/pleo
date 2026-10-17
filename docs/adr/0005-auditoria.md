# ADR 0005 — Extracción y auditoría (Épica C)

Fecha: 2026-10-17 · Estado: aceptada

## Decisiones

1. **La extracción ocurre al hacer el fetch** (`Crawling::PageExtractor`, `StructuredDataExtractor`) y se guarda en columnas de `pages`. Así la auditoría no vuelve a parsear el HTML. `bin/rails audit:reextract CRAWL_ID=…` repite la extracción desde `page_bodies` cuando mejore el extractor.
2. **La auditoría se lanza al completarse el crawl** (`Audit::RunAuditJob`, cola `audit`) y también se puede repetir con `POST /crawls/:id/audit`. Pasos: grafo de enlaces → enlaces externos → PageRank → datos del sitio → checks. Repetirla reemplaza los issues anteriores.
3. **Checks como clases con DSL** (`define key:, category:, severity:, weight:, title:, description:, fix:`). Los textos están escritos desde cero en español. `Audit::Catalog` es la lista ordenada y sincroniza `check_definitions` en cada auditoría.
4. **Los checks de enlaces se hacen en SQL** (`LinkQueryCheck`), agrupados por página origen, para no cargar millones de enlaces en Ruby. Los checks por página usan un `Context` con una sola consulta de columnas.
5. **Las cadenas y bucles de redirección** se reconstruyen siguiendo `redirect_url` entre páginas rastreadas (ver ADR 0004).
6. **PageRank interno**: enlaces seguidos (sin nofollow) entre páginas HTML 200, con amortiguación 0,85 y 20 iteraciones; el rango de las páginas sin salida se reparte entre todas. Las aristas se leen como dos arrays de Postgres. Con 50.000 nodos y 1 M de aristas tarda unos 6 s en Ruby.
7. **Casi duplicados** con SimHash de 64 bits sobre 3-shingles de palabras y distancia de Hamming ≤ 3. Se buscan con 4 bandas de 16 bits (por el principio del palomar, dos hashes a distancia ≤ 3 coinciden al menos en una banda), así que no hace falta comparar todos los pares.
8. **Datos estructurados**: JSON-LD (incluye `@graph`), Microdata y RDFa Lite. Se validan contra un snapshot del vocabulario de schema.org (`config/schema_org/vocabulary.json`, CC BY-SA, regenerable con `bin/rails schema_org:refresh`) y contra reglas propias de propiedades requeridas y recomendadas para 18 tipos, con herencia de tipos.
9. **Enlaces externos**: HEAD y, si lo rechazan (403/405/501), GET con `Range`. Una petición por segundo por host, respetando robots.txt, como máximo 1.000 URLs por crawl y 6 hilos. 429 y los bloqueos por robots no cuentan como enlace roto.
10. **Datos del sitio para GEO**: rastreadores de IA bloqueados en robots.txt (lista en `Audit::SiteFacts::AI_BOTS`) y presencia de `/llms.txt`.

## Cambios respecto al catálogo de docs/03 §5

- `perf.slow_ttfb` pasa a ser `perf.slow_response`: el rastreador mide el tiempo total de descarga del HTML, no el TTFB.
- `perf.lcp_poor`, `perf.cls_poor`, `perf.inp_poor` y `perf.score_low` llegan con PageSpeed Insights (Épica E).
- `ai.content_requires_js` llega con el renderizado JS (iteración 1.1).
- Se añadió `http.timeout` también para errores de conexión (cualquier fetch sin respuesta que no sea un error TLS).

## Limitaciones conocidas

- El texto para word count y SimHash solo quita `nav`, `header`, `footer`, scripts y similares; no detecta plantillas genéricas. En sitios con barras laterales grandes y poco contenido propio puede marcar como casi duplicadas páginas que no lo son. Por ejemplo, dos categorías de books.toscrape.com que comparten un menú lateral de 50 categorías.
- La validación de schema.org no comprueba rangos de valores (tipos esperados por propiedad) ni enumeraciones.
- La comprobación de robots.txt para enlaces externos se cachea en memoria solo durante una auditoría.
