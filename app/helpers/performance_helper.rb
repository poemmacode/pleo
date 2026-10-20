module PerformanceHelper
  # Lighthouse bands: 90+ good, 50–89 needs improvement, below 50 poor.
  def psi_score_class(score)
    return "health-none" if score.nil?

    score >= 90 ? "health-good" : score >= 50 ? "health-fair" : "health-poor"
  end

  def format_ms(ms)
    return "—" if ms.nil?

    ms >= 1000 ? "#{number_with_precision(ms / 1000.0, precision: 1)} s" : "#{ms} ms"
  end

  def format_cls(cls) = cls.nil? ? "—" : number_with_precision(cls, precision: 2)

  def field_summary(result)
    return t("performance.no_field_data") unless result.field_scope

    t("performance.field_summary",
      category: t("performance.field_categories.#{result.field_category}", default: result.field_category.to_s.downcase),
      where: t("performance.field_scopes.#{result.field_scope}"),
      lcp: format_ms(result.field_lcp_ms), inp: format_ms(result.field_inp_ms), cls: format_cls(result.field_cls))
  end
end
