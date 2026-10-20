# ADR 0009 — Exportable reports (Epic F)

Date: 2026-10-20 · Status: accepted

## Decisions

1. **Four reports per crawl**:
   - Pages (CSV);
   - Issues (CSV, sorted by priority);
   - Full Excel report: Summary, Issues, Findings, Pages, Broken links, Duplicates, Structured data and Performance, with a frozen header row and filters;
   - PDF executive summary: health, categories, the top 10 issues with how to fix them, performance and crawl facts.
2. **Generated asynchronously** (`Reports::GenerateReportJob`, `reports` queue). The list is updated through Turbo Streams on the same channel as the progress.
3. **The file is stored in Postgres** (`reports.data`), not on disk or S3: Render's free disk is wiped on every restart. Only the latest report of each kind per crawl is kept, and listings never load the content (`Report.without_data`). If reports grow, they would move to Active Storage with S3.
4. **Download** through `GET /crawls/:id/reports/:id`, as an attachment and only for the crawl's owner (404 for everyone else).
5. **CSV injection protection.** Titles, descriptions, anchors and URLs come from third-party sites. Any cell starting with `=`, `+`, `-`, `@`, tab or carriage return gets a `'` prefix (OWASP recommendation). In Excel, text cells are also written with the string type and `Axlsx.escape_formulas = true`, so they are never formulas.
6. **CSV in UTF-8 with a BOM**, so Excel shows accented characters correctly.
7. **PDF with Prawn's built-in fonts**, without downloading or bundling fonts. They cover Windows-1252, enough for English and Spanish. Common symbols (→, ≥, −, ▲, ▼) are transliterated and any other character is replaced with `?`. Kerning is off so the PDF text is searchable.
8. **Pure-Ruby gems**: `caxlsx` and `prawn` + `prawn-table`. Prawn requires `bigdecimal` 3.x.
9. **Language**: each report is written in the language of the user who requested it (`reports.locale`, [ADR 0010](0010-internationalization.md)), including column headers, sheet names, severities and check texts.

## Measurements

- 10,000 pages to CSV and Excel in under 60 s (`:slow` spec).
- In the local test with 20 pages: 16 KB PDF and 21 KB Excel file.

## Limitations

- Text in non-Latin scripts (e.g. Japanese titles) shows up as `?` in the PDF; CSV and Excel keep it.
- Reports for very large crawls take up space in the free Postgres (1 GB).
