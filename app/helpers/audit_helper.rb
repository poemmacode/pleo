module AuditHelper
  SEVERITY_LABELS = { "error" => "Errores", "warning" => "Avisos", "notice" => "Notas" }.freeze
  SEVERITY_BADGES = { "error" => "Error", "warning" => "Aviso", "notice" => "Nota" }.freeze

  # good ≥ 80, fair ≥ 50, poor below.
  def health_class(score)
    return "health-none" if score.nil?

    score >= 80 ? "health-good" : score >= 50 ? "health-fair" : "health-poor"
  end

  def format_score(score) = number_with_precision(score, precision: 1, strip_insignificant_zeros: true, separator: ",")

  def score_delta(current, previous)
    return if current.nil? || previous.nil?

    delta = (current - previous).round(1)
    return tag.span("= sin cambios", class: "muted") if delta.zero?

    tag.span("#{delta.positive? ? "▲ +" : "▼ "}#{format_score(delta)}", class: delta.positive? ? "delta-up" : "delta-down")
  end

  def severity_badge(severity)
    tag.span(SEVERITY_BADGES.fetch(severity, severity), class: "badge sev-#{severity}")
  end

  # Short, readable rendering of a finding's details ({ "status" => 404 } → "status: 404").
  def format_details(details)
    details.map do |key, value|
      text = value.is_a?(Array) ? value.first(3).join(", ") + (value.size > 3 ? "…" : "") : value.to_s
      "#{key}: #{text}"
    end.join(" · ")
  end
end
