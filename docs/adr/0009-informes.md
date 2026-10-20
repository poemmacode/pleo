# ADR 0009 — Informes exportables (Épica F)

Fecha: 2026-10-20 · Estado: aceptada

## Decisiones

1. **Cuatro informes por crawl**:
   - Páginas (CSV);
   - Problemas (CSV, ordenados por prioridad);
   - Informe completo en Excel: Resumen, Problemas, Hallazgos, Páginas, Enlaces rotos, Duplicados, Datos estructurados y Rendimiento, con fila de cabecera fija y filtros;
   - Resumen ejecutivo en PDF: salud, categorías, los 10 problemas prioritarios con cómo arreglarlos, rendimiento y datos del rastreo.
2. **Generación asíncrona** (`Reports::GenerateReportJob`, cola `reports`). La lista se actualiza por Turbo Streams en el mismo canal que el progreso.
3. **El archivo se guarda en Postgres** (`reports.data`), no en disco ni en S3: el disco de Render gratis se borra en cada reinicio. Solo se conserva el último informe de cada tipo por crawl, y los listados nunca cargan el contenido (`Report.without_data`). Si los informes crecieran, se pasaría a Active Storage con S3.
4. **Descarga** por `GET /crawls/:id/reports/:id`, como adjunto y solo para el dueño del crawl (404 para los demás).
5. **Protección contra CSV injection.** Títulos, descripciones, anchors y URLs vienen de sitios de terceros. Cualquier celda que empiece por `=`, `+`, `-`, `@`, tabulador o retorno de carro se prefija con `'` (recomendación OWASP). Además, en Excel las celdas de texto se escriben con tipo string y `Axlsx.escape_formulas = true`, así que nunca son fórmulas.
6. **CSV en UTF-8 con BOM**, para que Excel muestre bien los acentos.
7. **PDF con las fuentes integradas de Prawn**, sin descargar ni empaquetar fuentes. Cubren Windows-1252, suficiente para el español. Los símbolos habituales (→, ≥, −, ▲, ▼) se transliteran y el resto de caracteres se sustituyen por `?`. El kerning va desactivado para que el texto del PDF sea buscable.
8. **Gemas en Ruby puro**: `caxlsx` y `prawn` + `prawn-table`. Prawn obliga a usar `bigdecimal` 3.x.

## Medidas

- 10 000 páginas a CSV y Excel en menos de 60 s (spec `:slow`).
- En la prueba local con 20 páginas: PDF de 16 KB y Excel de 21 KB.

## Limitaciones

- Textos en alfabetos no latinos (por ejemplo, títulos en japonés) aparecen como `?` en el PDF; el CSV y el Excel los conservan.
- Los informes de crawls muy grandes ocupan sitio en el Postgres gratuito (1 GB).
