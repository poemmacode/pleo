module Audit
  module Checks
    module MobilePerformance
      class ViewportMissing < PageCheck
        define key: "mobile.viewport_missing", category: "mobile", severity: "warning", weight: 5,
          title: "Falta la meta viewport",
          description: "Sin viewport, los móviles muestran la versión de escritorio reducida; perjudica la usabilidad móvil.",
          fix: "Añade <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">."

        def evaluate(page) = page.viewport.nil?
      end

      class PageTooLarge < PageCheck
        LIMIT = 2 * 1024 * 1024
        define key: "page.too_large", category: "performance", severity: "notice", weight: 2,
          title: "HTML demasiado pesado",
          description: "Más de 2 MB de HTML ralentiza la carga y el rastreo.",
          fix: "Reduce el HTML: elimina datos incrustados, CSS/JS en línea innecesario o listados enormes."

        def evaluate(page) = (page.truncated || page.content_length.to_i > LIMIT) && { bytes: page.content_length, truncated: page.truncated }
      end

      class SlowResponse < PageCheck
        LIMIT_MS = 1500
        define key: "perf.slow_response", category: "performance", severity: "notice", weight: 2,
          title: "Respuesta lenta del servidor",
          description: "La descarga del HTML tardó más de 1,5 s (medido por el rastreador, sin recursos).",
          fix: "Revisa caché, base de datos y tiempo de generación de la página en el servidor."

        def evaluate(page) = page.response_ms.to_i > LIMIT_MS && { ms: page.response_ms }
      end

      # Core Web Vitals from PageSpeed Insights, only on the measured sample.
      class PerformanceCheck < PageCheck
        def applies?(page) = super && context.performance(page.id).present?

        def result(page) = context.performance(page.id)
      end

      class LcpPoor < PerformanceCheck
        sampled!
        define key: "perf.lcp_poor", category: "performance", severity: "warning", weight: 5,
          title: "LCP lento (más de 4 s)",
          description: "El elemento principal tarda más de 4 s en mostrarse en móvil; los usuarios perciben la página como lenta.",
          fix: "Optimiza la imagen o bloque principal (tamaño, formato, preload), reduce el CSS/JS que bloquea el render y mejora el TTFB."

        def evaluate(page)
          value, source = result(page).lcp_value
          value && value > PerformanceResult::POOR[:lcp_ms] && { lcp_ms: value, source: }
        end
      end

      class ClsPoor < PerformanceCheck
        sampled!
        define key: "perf.cls_poor", category: "performance", severity: "warning", weight: 4,
          title: "Diseño inestable (CLS mayor de 0,25)",
          description: "El contenido se desplaza mientras carga, lo que provoca clics por error y una mala experiencia.",
          fix: "Reserva espacio para imágenes, anuncios e incrustaciones (width/height o aspect-ratio) y evita insertar contenido encima del existente."

        def evaluate(page)
          value, source = result(page).cls_value
          value && value > PerformanceResult::POOR[:cls] && { cls: value, source: }
        end
      end

      class InpPoor < PerformanceCheck
        sampled!
        define key: "perf.inp_poor", category: "performance", severity: "warning", weight: 4,
          title: "Respuesta lenta a la interacción (INP mayor de 500 ms)",
          description: "Según usuarios reales (CrUX), la página tarda en reaccionar a clics y toques.",
          fix: "Divide las tareas largas de JavaScript, aplaza scripts de terceros y reduce el trabajo en los manejadores de eventos."

        def evaluate(page)
          performance = result(page)
          performance.field_scope == "url" && performance.field_inp_ms.to_i > PerformanceResult::POOR[:inp_ms] &&
            { inp_ms: performance.field_inp_ms }
        end
      end

      class ScoreLow < PerformanceCheck
        sampled!
        define key: "perf.score_low", category: "performance", severity: "notice", weight: 2,
          title: "Puntuación de rendimiento baja",
          description: "Lighthouse puntúa el rendimiento móvil por debajo de 50 sobre 100.",
          fix: "Revisa las oportunidades que indica PageSpeed para esta página, empezando por las de más ahorro."

        def evaluate(page)
          score = result(page).performance_score
          score && score < 50 && { score: }
        end
      end
    end
  end
end
