# Report libraries (Épica F).

# Never let cell text that starts with "=" become a live formula in generated workbooks (see Reports.safe_cell).
Axlsx.escape_formulas = true

# The PDF summary converts all text to Windows-1252 itself (Reports::ExecutiveSummary#text), so Prawn's
# warning about built-in fonts and UTF-8 does not apply.
Prawn::Fonts::AFM.hide_m17n_warning = true
