class PerformanceResult < ApplicationRecord
  belongs_to :crawl
  belongs_to :page

  # Thresholds for "poor" Core Web Vitals (web.dev definitions).
  POOR = { lcp_ms: 4_000, cls: 0.25, inp_ms: 500 }.freeze

  def ok? = error.nil?

  # Field (real users) data when available for this page, otherwise the lab value.
  def lcp_value = field_scope == "url" && field_lcp_ms ? [ field_lcp_ms, "campo" ] : [ lcp_ms, "laboratorio" ]

  def cls_value = field_scope == "url" && field_cls ? [ field_cls, "campo" ] : [ cls, "laboratorio" ]
end
