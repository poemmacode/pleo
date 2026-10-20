module Performance
  # Turns a PSI v5 response into PerformanceResult attributes.
  module Parser
    LAB_AUDITS = {
      lcp_ms: "largest-contentful-paint", cls: "cumulative-layout-shift", tbt_ms: "total-blocking-time",
      fcp_ms: "first-contentful-paint", speed_index_ms: "speed-index", ttfb_ms: "server-response-time"
    }.freeze
    FIELD_METRICS = {
      field_lcp_ms: "LARGEST_CONTENTFUL_PAINT_MS", field_cls: "CUMULATIVE_LAYOUT_SHIFT_SCORE",
      field_inp_ms: "INTERACTION_TO_NEXT_PAINT"
    }.freeze
    MAX_OPPORTUNITIES = 5

    module_function

    def parse(body)
      lighthouse = body.fetch("lighthouseResult") { raise Client::Error, "respuesta sin lighthouseResult" }
      if (runtime = lighthouse["runtimeError"]) && runtime["code"] != "NO_ERROR"
        raise Client::Error, "Lighthouse: #{runtime["message"] || runtime["code"]}".first(300)
      end

      audits = lighthouse.fetch("audits", {})
      score = lighthouse.dig("categories", "performance", "score")
      lab = LAB_AUDITS.to_h do |attr, id|
        value = audits.dig(id, "numericValue")
        [ attr, value && (attr == :cls ? value.round(3) : value.round) ]
      end

      { performance_score: score && (score * 100).round, opportunities: opportunities(audits) }
        .merge(lab).merge(field(body["loadingExperience"]))
    end

    # Lighthouse ≤ 11 reports details.overallSavingsMs; 12+ reports metricSavings per metric.
    def opportunities(audits)
      audits.filter_map do |id, audit|
        savings = audit.dig("details", "overallSavingsMs") ||
                  audit["metricSavings"]&.slice("LCP", "FCP")&.values&.compact&.max
        next unless savings.to_f >= 100 && audit["score"].to_f < 0.9

        { id:, title: audit["title"].to_s.first(200), savings_ms: savings.round }
      end.sort_by { -_1[:savings_ms] }.first(MAX_OPPORTUNITIES)
    end

    # CrUX p75 values; CLS percentile is reported ×100.
    def field(experience)
      metrics = experience&.dig("metrics")
      return { field_scope: nil } if metrics.blank?

      values = FIELD_METRICS.to_h do |attr, key|
        percentile = metrics.dig(key, "percentile")
        [ attr, percentile && (attr == :field_cls ? (percentile / 100.0).round(3) : percentile.round) ]
      end
      values.merge(field_scope: experience["origin_fallback"] ? "origin" : "url", field_category: experience["overall_category"])
    end
  end
end
