# ADR 0004 — Motor de crawling (Épica B)

Fecha: 2026-10-17 · Estado: aceptada

## Decisiones

1. **Lanes en lugar de un job por URL.** El lane se reencola de inmediato, no con `wait`: un job programado no empieza hasta la siguiente consulta de Sidekiq (unos 5 s), y eso bajaba un crawl a 0,5 req/s hasta unas 0,19 req/s reales. Solo se programa cuando el limitador pide esperar más de 2 s (corregido el 2026-10-17). `Crawling::FetchLaneJob` reclama la siguiente URL de `crawl_urls` (`FOR UPDATE SKIP LOCKED`, orden BFS por `depth`), la procesa y se reencola. Pausar o cancelar corta las peticiones nuevas de inmediato (el lane comprueba el estado al empezar) y no hay que purgar miles de jobs. El número de lanes (1–4) solo da paralelismo; la velocidad la fija `HostRateLimiter`, así que lanzar lanes de más no tiene efecto.
2. **Presupuesto atómico.** `pages_claimed` se incrementa con un `UPDATE … WHERE pages_claimed < max_pages`; se devuelve al omitir o reencolar. Así `max_pages` nunca se supera aunque haya lanes concurrentes.
3. **Las redirecciones no se siguen dentro de una petición.** Cada URL se pide con `follow_redirects: false`. Un 3xx se guarda como página (`redirect_url`) y el destino entra en la frontera (`source = redirect`). Las cadenas y bucles se reconstruyen en la Épica C a partir del grafo; por eso no existe la columna `redirect_chain` que proponía el diseño.
4. **robots.txt por host** (`crawl_hosts`), descargado la primera vez que se necesita. El alcance `domain` puede abarcar varios subdominios, y cada uno tiene su propio robots.txt. Si es inaccesible (5xx, 429, error) no se rastrea ese host (RFC 9309). Si el host es el inicial, el crawl termina con `robots_unreachable`.
5. **Alcance `domain` = host verificado y los que cuelgan de él.** Verificar `www.example.com` no autoriza `blog.example.com`.
6. **Sitemaps** en un job aparte, en paralelo con el crawl: los de robots.txt más `/sitemap.xml`, índices hasta 3 niveles, un máximo de 200 archivos y 50 MB descomprimidos por archivo. Se leen en streaming con `Nokogiri::XML::Reader` (`NONET`, sin entidades externas). Solo se descargan sitemaps alojados en hosts del dominio verificado. Las URLs de sitemap entran con `depth = NULL` (van al final de la cola) y, si después aparecen enlazadas, se quedan con la profundidad menor. Al terminar el crawl, `depth` e `in_sitemap` se sincronizan en `pages`.
7. **Límite de descubrimiento**: como mucho `10 × max_pages` URLs en la frontera.
8. **HTML guardado** comprimido con gzip en `page_bodies` (opción `store_html`, activada por defecto), para que las comprobaciones de la Épica C se puedan repetir sin volver a descargar. Queda pendiente una política de retención.
9. **Reintentos**: 429/503 (respetando `Retry-After` vía `penalize`) y errores de conexión, hasta 3 intentos. Los timeouts se registran directamente como fallo (`fetch_error`).
10. **Velocidad adaptativa**: `SafeHttp::AdaptiveRate` se persiste en `crawls.adaptive_rate` bajo `with_lock`. Con `:pause`, el crawl pasa a `paused` con `status_reason = server_overloaded`.

## Cambio posterior (2026-10-20)

Límites para dominios **sin verificar** ampliados de 200 páginas a 0,5 req/s a **2 000 páginas y 2 req/s**, con valores por defecto de 500 páginas a 1 req/s. Se mantiene la confirmación de términos. Motivo: con 200 páginas no se podían hacer auditorías útiles de sitios propios sin verificarlos antes. 2 req/s sigue siendo una carga baja para cualquier servidor, y `robots.txt`, `Crawl-delay` y la velocidad adaptativa siguen aplicándose.

## Limitaciones

- La prueba de integración ejecuta los jobs en línea (`perform_enqueued_jobs`), así que no ejerce concurrencia real. La concurrencia se probó a mano con Sidekiq contra books.toscrape.com: 20 páginas a 0,5 req/s, separación mínima medida de 1,9 s.
- Los claims abandonados por un worker caído se recuperan pasados 2 minutos, pero solo cuando otro lane llega a `maybe_finish` o se reanuda el crawl. Falta un watchdog periódico para crawls sin ningún lane vivo (sidekiq-cron, Épica K).
