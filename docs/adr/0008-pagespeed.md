# ADR 0008 — Rendimiento con PageSpeed Insights (Épica E)

Fecha: 2026-10-20 · Estado: aceptada

## Decisiones

1. **Una sola fuente: PSI v5.** Su respuesta incluye el laboratorio de Lighthouse y los datos de campo de CrUX (`loadingExperience`, p75 de 28 días), así que no hace falta llamar aparte a la CrUX API. Los datos de campo pueden ser de la página o del origen (`origin_fallback`); los de origen se muestran como "todo el sitio" y no se usan en los checks.
2. **Hace falta una API key** (`PAGESPEED_API_KEY`). La cuota anónima es compartida y en la prueba del 2026-10-20 devolvió 429 ("Queries per day"). Sin key, la auditoría marca `performance_status = skipped_no_key` y la interfaz lo explica.
3. **Muestra, no todo el sitio.** `Performance::Sampler` elige, por este orden, la página inicial, una página por plantilla de URL (la de más PageRank) y después las de más PageRank, hasta `pagespeed_sample` (10 por defecto, máximo 30). Una plantilla agrupa URLs cuyos números y último segmento difieren (`/blog/:n/*`). Solo cuentan páginas HTML 200 indexables.
4. **Dentro de la auditoría**, después del PageRank y antes de los checks. Se hacen 4 mediciones a la vez, 1 petición por segundo a `www.googleapis.com` (con `HostRateLimiter`) y hay un tope diario global en Redis (`PAGESPEED_DAILY_LIMIT`, 500 por defecto). Si el tope corta la muestra, `performance_status = limited`. Los errores de una página se guardan en su resultado y no rompen la auditoría.
5. **La key nunca aparece en errores ni logs**: el cliente solo propaga el mensaje de PSI, no la URL de la petición.
6. **Checks** (sobre las páginas medidas):
   - `perf.lcp_poor`: LCP > 4 s.
   - `perf.cls_poor`: CLS > 0,25.
   - `perf.inp_poor`: INP > 500 ms; solo con datos de campo de la página, porque el INP de laboratorio no existe.
   - `perf.score_low`: puntuación < 50.
   LCP y CLS usan el dato de campo de la página si existe y, si no, el de laboratorio; el hallazgo indica cuál se usó. En la salud, estos checks son `sampled!`: su cobertura es afectadas / medidas, no afectadas / rastreadas.
7. **Oportunidades**: se guardan las 5 de mayor ahorro de 100 ms o más. Se soportan `details.overallSavingsMs` (Lighthouse ≤ 11) y `metricSavings` (Lighthouse 12+, máximo de LCP/FCP).

## Limitaciones

- El parser se escribió a partir de la estructura documentada de PSI v5 y se probó con respuestas sintéticas. Falta comprobarlo contra una respuesta real cuando haya key.
- Solo se mide la estrategia móvil; la columna `strategy` permite añadir escritorio.
