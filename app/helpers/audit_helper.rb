module AuditHelper
  SEVERITY_LABELS = { "error" => "Errores", "warning" => "Avisos", "notice" => "Notas" }.freeze
  SEVERITY_BADGES = { "error" => "Error", "warning" => "Aviso", "notice" => "Nota" }.freeze

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
