class Report < ApplicationRecord
  KINDS = {
    "pages_csv" => { label: "Páginas (CSV)", extension: "csv", content_type: "text/csv; charset=utf-8" },
    "issues_csv" => { label: "Problemas (CSV)", extension: "csv", content_type: "text/csv; charset=utf-8" },
    "xlsx" => { label: "Informe completo (Excel)", extension: "xlsx",
                content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" },
    "pdf" => { label: "Resumen ejecutivo (PDF)", extension: "pdf", content_type: "application/pdf" }
  }.freeze

  belongs_to :crawl

  validates :kind, inclusion: { in: KINDS.keys }

  # Listing never loads the file contents.
  scope :without_data, -> { select(column_names - [ "data" ]) }

  def label = KINDS.fetch(kind)[:label]

  def done? = status == "done"

  def default_filename
    stamp = (crawl.finished_at || crawl.created_at).strftime("%Y%m%d")
    suffix = { "pages_csv" => "paginas", "issues_csv" => "problemas", "xlsx" => "informe", "pdf" => "resumen" }.fetch(kind)
    "seo-#{crawl.domain.host}-#{stamp}-#{suffix}.#{KINDS.fetch(kind)[:extension]}"
  end
end
