# Exportable audit reports (Épica F).
module Reports
  # Cell values that start like a formula would run in Excel/Sheets/LibreOffice when the file is opened
  # (CSV injection). Page titles, anchors and URLs come from third-party sites, so every text cell is
  # neutralised by prefixing an apostrophe (OWASP recommendation).
  FORMULA_START = /\A[=+\-@\t\r]/

  def self.safe_cell(value)
    return value unless value.is_a?(String)

    value.match?(FORMULA_START) ? "'#{value}" : value
  end
end
