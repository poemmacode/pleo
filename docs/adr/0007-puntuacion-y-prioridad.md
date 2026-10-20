# ADR 0007 — Puntuación de salud y prioridad de problemas (Épica D)

Fecha: 2026-10-20 · Estado: aceptada · Ajusta las fórmulas de docs/03 §6

## Decisiones

Implementadas en `Audit::Scoring`, que se ejecuta al final de cada auditoría.

1. **Cobertura de un check**: proporción de páginas rastreadas (de cualquier estado) con el hallazgo, como máximo 1. Los checks de sitio entero (`site_wide!`: sin sitemap, bots de IA bloqueados, sin llms.txt) cuentan siempre como 1.
2. **Penalización**: `peso × factor de severidad × √cobertura`. La raíz evita que un problema en el 1 % de las páginas sea irrelevante y que uno en el 100 % pese de forma lineal.
3. **Puntuación por categoría**: `100 × (1 − Σ penalización / Σ peso × factor)` sobre todos los checks de la categoría.
4. **Salud global**: media ponderada de las categorías: rastreabilidad 22, indexabilidad 18, enlaces 14, metadatos 14, contenido 10, HTTPS 6, datos estructurados 5, móvil 5, rendimiento 3 y búsqueda con IA 3 (total 100). Un sitio sin hallazgos da 100; todos los checks fallando en todas las páginas dan 0.
5. **Notas al 25 %**. Los avisos de severidad *notice* cuentan con un cuarto de su peso en todas partes. *Cambio respecto a docs/03*: allí las notas restaban "como máximo 5 puntos globales", pero la categoría de rendimiento solo tiene notas hasta que llegue PageSpeed (Épica E) y con esa regla no tendría puntuación. Un único factor es más simple y consistente.
6. **Prioridad de cada hallazgo** (0–100): `10 × peso × factor × (0,5 × cobertura + 0,5 × importancia)`.
   - La importancia es el PageRank interno relativo al máximo del crawl.
   - Para páginas fuera del grafo (errores, redirecciones) se usan los enlaces entrantes relativos al máximo.
   - Los hallazgos sin página cuentan como importancia 1.
   - La prioridad de un check es la media de sus hallazgos. El informe ordena los checks por ella y, dentro de cada check, las páginas de más a menos importante (paginación por número de página).
7. **Comparación**: la página del crawl muestra la diferencia con el crawl anterior del mismo dominio que tenga puntuación.

## Pendiente

- Cuando haya Search Console, la importancia combinará PageRank e impresiones (docs/03 §6).
- Los pesos son un punto de partida y deberían calibrarse con auditorías reales.
