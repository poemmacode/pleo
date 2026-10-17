# ADR 0006 — Monolito Rails con Hotwire

Fecha: 2026-10-17 · Estado: aceptada · Sustituye la parte de `api/` + `web/` (React) del ADR 0001

## Contexto

El MVP tenía dos aplicaciones: Rails 8 en modo API (`/api/v1`, JSON) y una SPA de React 19 con Vite. Para una herramienta personal eso suponía dos toolchains (Ruby y Node), contratos JSON duplicados en tipos de TypeScript, CSRF por cabecera y un proxy de desarrollo. El usuario pidió un único monolito Rails con la interfaz en Turbo/Hotwire.

## Decisiones

1. **Un solo Rails en la raíz del repositorio** (antes `api/`). Se elimina `web/`, junto con Node, Vite, Vitest y MSW.
2. **Sin API JSON.** Los controladores HTML usan los mismos servicios que usaba la API: `Crawling::CreateCrawl`, `Crawling::Lifecycle`, `Domain::Verifier`, `Audit::Summary` y `Audit::NearDuplicates`. Si en el futuro hace falta una API, se añadirá como un namespace aparte sobre esos servicios.
3. **Propshaft + importmap**, sin paso de build. Turbo y Stimulus se sirven desde las gemas. La hoja de estilos de la SPA se conserva tal cual en `app/assets/stylesheets/application.css`.
4. **Turbo para la navegación**:
   - Frames diferidos para la tabla de páginas y para los hallazgos de cada check (se cargan al abrir su `<details>`).
   - "Cargar más" con respuestas Turbo Stream (`append`) y paginación por keyset (`CrawlScoped#keyset`).
   - Confirmaciones con `data-turbo-confirm`.
5. **Stimulus solo donde aporta**:
   - `verification-method`: muestra las instrucciones del método elegido.
   - `domain-switch`: recarga el formulario de crawl para el dominio elegido, con sus valores por defecto y límites.
   - `autosubmit`: aplica los filtros al cambiarlos.
   Todo lo demás funciona sin JavaScript.
6. **Progreso en vivo con Turbo Streams sobre Action Cable** (`Crawling::ProgressBroadcaster`):
   - La página del crawl se suscribe a `[crawl, :progress]`, y los jobs reemplazan los parciales `crawls/_progress` y `crawls/_audit`.
   - Los lanes llaman al broadcaster después de cada URL, con límite: `SET NX PX 2000` en Redis, como mucho un broadcast cada 2 s por crawl.
   - Las transiciones (inicio, pausa, reanudación, cancelación, fin, estados de la auditoría y pausa automática) usan `force: true`.
   - Los parciales dependen solo del crawl, así que se pueden renderizar fuera de una petición. Los botones que contienen funcionan porque Turbo envía el token CSRF del `<meta>` en la cabecera.
7. **Seguridad de Cable**: `ApplicationCable::Connection` exige la misma sesión de servidor que las páginas (cookie firmada `session_id`) y rechaza las conexiones anónimas. Turbo firma los nombres de stream, así que solo se puede suscribir quien recibió la página.
8. **CSRF estándar de Rails** (token en formularios y `<meta>`). Desaparecen el endpoint `csrf_token` y el ajuste manual de `allow_forgery_protection`.
9. **System specs con Cuprite** (Chrome sin cabeza vía CDP), en lugar de Selenium. Selenium necesita `chromedriver`, que no estaba instalado y Selenium Manager habría descargado automáticamente. Cuprite usa el Chrome ya presente (`CHROME_PATH` en CI). En los system specs Action Cable usa el adaptador `async`, para que los broadcasts lleguen al navegador; el resto de specs usa `test`.

## Consecuencias

- Una sola suite: RSpec con request specs HTML, system specs y los specs de dominio, que no cambiaron.
- Se pierde la API pública, que nadie usaba todavía. Los documentos de diseño marcan esa sección como sustituida.
- `?domain_id=` en lugar de `?domain=`: `domain` es una opción reservada de `url_for` (el host).
