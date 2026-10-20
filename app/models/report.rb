class Report < ApplicationRecord
  # Labels are translated under reports.kinds.
  KINDS = {
    "pages_csv" => { extension: "csv", content_type: "text/csv; charset=utf-8", suffix: "pages" },
    "issues_csv" => { extension: "csv", content_type: "text/csv; charset=utf-8", suffix: "issues" },
    "xlsx" => { extension: "xlsx", content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", suffix: "report" },
    "pdf" => { extension: "pdf", content_type: "application/pdf", suffix: "summary" }
  }.freeze

  belongs_to :crawl

  validates :kind, inclusion: { in: KINDS.keys }
  validates :locale, inclusion: { in: -> { I18n.available_locales.map(&:to_s) } }

  # Listing never loads the file contents.
  scope :without_data, -> { select(column_names - [ "data" ]) }

  def done? = status == "done"

  def default_filename
    stamp = (crawl.finished_at || crawl.created_at).strftime("%Y%m%d")
    info = KINDS.fetch(kind)
    "seo-#{crawl.domain.host}-#{stamp}-#{info[:suffix]}.#{info[:extension]}"
  end
end
