module PerformanceHelper
  FIELD_CATEGORIES = { "FAST" => "rápida", "AVERAGE" => "mejorable", "SLOW" => "lenta" }.freeze

  # Lighthouse bands: 90+ good, 50–89 needs improvement, below 50 poor.
  def psi_score_class(score)
    return "health-none" if score.nil?

    score >= 90 ? "health-good" : score >= 50 ? "health-fair" : "health-poor"
  end

  def format_ms(ms)
    return "—" if ms.nil?

    ms >= 1000 ? "#{number_with_precision(ms / 1000.0, precision: 1, separator: ",")} s" : "#{ms} ms"
  end

  def format_cls(cls) = cls.nil? ? "—" : number_with_precision(cls, precision: 2, separator: ",")

  def field_summary(result)
    return "sin datos de usuarios reales" unless result.field_scope

    scope = result.field_scope == "origin" ? "todo el sitio" : "esta página"
    "#{FIELD_CATEGORIES.fetch(result.field_category, result.field_category.to_s.downcase)} (#{scope}): " \
      "LCP #{format_ms(result.field_lcp_ms)}, INP #{format_ms(result.field_inp_ms)}, CLS #{format_cls(result.field_cls)}"
  end
end
