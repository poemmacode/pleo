# SEO Platform — documentación de diseño

Plataforma SEO **personal, independiente y no comercial**. Toma como referencia de *producto* la funcionalidad públicamente observable de Semrush, pero toda la implementación, los datos y los algoritmos son propios o provienen de fuentes autorizadas. No se copia código, bases de datos, textos, métricas propietarias ni assets de terceros.

Estado: diseño aprobado el 2026-10-16. Épica 0 implementada (ver `../README.md`).

| Documento | Contenido |
|---|---|
| [01-analisis-producto.md](01-analisis-producto.md) | Fase 1: método, evidencia, límites e inventario de los 8 módulos |
| [02-arquitectura.md](02-arquitectura.md) | Fase 2: stack, diagrama, módulos, esquema de BD, rutas, roadmap |
| [03-mvp-crawler.md](03-mvp-crawler.md) | Fase 3: diseño del crawler técnico, seguridad (SSRF / DNS rebinding), catálogo de checks |
| [04-backlog.md](04-backlog.md) | Backlog del MVP y siguientes fases con criterios de aceptación |
| [05-fuentes-datos-costos.md](05-fuentes-datos-costos.md) | Fuentes de datos autorizadas, cuotas y costos estimados |
| [06-flujo-trabajo.md](06-flujo-trabajo.md) | Fase 4: estado del repositorio, ubicación propuesta, flujo de trabajo, decisiones pendientes |
| [adr/](adr/) | Decisiones de arquitectura tomadas durante la implementación |

## Principios

1. **Primero lo propio y gratuito**: crawler propio + Google Search Console + PageSpeed Insights/CrUX antes que APIs de pago.
2. **Datos autorizados**: solo APIs oficiales o proveedores con licencia. Nada de scraping de SERPs de Google ni de interfaces de chatbots (violan sus términos).
3. **Crawling responsable**: robots.txt, límites de velocidad, presupuesto de crawl, User-Agent identificable, y crawl completo solo de dominios verificados por el usuario.
4. **Seguridad por defecto**: el crawler es un cliente HTTP que acepta URLs del usuario → se trata como superficie SSRF desde el día 1.
5. **Vertical slices**: cada módulo se entrega de punta a punta (BD → job → API → UI → tests) antes de empezar el siguiente.
