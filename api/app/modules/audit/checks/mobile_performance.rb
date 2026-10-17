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
    end
  end
end
