module Audit
  module Checks
    module MobilePerformance
      class ViewportMissing < PageCheck
        define key: "mobile.viewport_missing", category: "mobile", severity: "warning", weight: 5

        def evaluate(page) = page.viewport.nil?
      end

      class PageTooLarge < PageCheck
        LIMIT = 2 * 1024 * 1024
        define key: "page.too_large", category: "performance", severity: "notice", weight: 2

        def evaluate(page) = (page.truncated || page.content_length.to_i > LIMIT) && { bytes: page.content_length, truncated: page.truncated }
      end

      class SlowResponse < PageCheck
        LIMIT_MS = 1500
        define key: "perf.slow_response", category: "performance", severity: "notice", weight: 2

        def evaluate(page) = page.response_ms.to_i > LIMIT_MS && { ms: page.response_ms }
      end

      # Core Web Vitals from PageSpeed Insights, only on the measured sample.
      class PerformanceCheck < PageCheck
        def applies?(page) = super && context.performance(page.id).present?

        def result(page) = context.performance(page.id)
      end

      class LcpPoor < PerformanceCheck
        sampled!
        define key: "perf.lcp_poor", category: "performance", severity: "warning", weight: 5

        def evaluate(page)
          value, source = result(page).lcp_value
          value && value > PerformanceResult::POOR[:lcp_ms] && { lcp_ms: value, source: }
        end
      end

      class ClsPoor < PerformanceCheck
        sampled!
        define key: "perf.cls_poor", category: "performance", severity: "warning", weight: 4

        def evaluate(page)
          value, source = result(page).cls_value
          value && value > PerformanceResult::POOR[:cls] && { cls: value, source: }
        end
      end

      class InpPoor < PerformanceCheck
        sampled!
        define key: "perf.inp_poor", category: "performance", severity: "warning", weight: 4

        def evaluate(page)
          performance = result(page)
          performance.field_scope == "url" && performance.field_inp_ms.to_i > PerformanceResult::POOR[:inp_ms] &&
            { inp_ms: performance.field_inp_ms }
        end
      end

      class ScoreLow < PerformanceCheck
        sampled!
        define key: "perf.score_low", category: "performance", severity: "notice", weight: 2

        def evaluate(page)
          score = result(page).performance_score
          score && score < 50 && { score: }
        end
      end
    end
  end
end
