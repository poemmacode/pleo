module Reports
  # Full audit workbook: summary, problems, findings, pages, broken links, duplicates, structured data
  # and performance, one sheet each, with frozen header rows and filters.
  class Workbook
    def initialize(crawl)
      @crawl = crawl
      @dataset = Dataset.new(crawl)
    end

    def render
      package = Axlsx::Package.new
      package.use_shared_strings = true
      book = package.workbook
      @header = book.styles.add_style(b: true, bg_color: "E8EEF9", border: { style: :thin, color: "C9D3E6" })
      @title = book.styles.add_style(b: true, sz: 14)

      summary_sheet(book)
      table_sheet(book, "Problemas", [ "Prioridad", "Severidad", "Categoría", "Problema", "Hallazgos", "Cómo arreglarlo" ],
                  @dataset.summary.entries.map { |e| [ e.priority, Dataset::SEVERITY_LABELS[e.severity], Audit::Scoring::CATEGORY_LABELS[e.category], e.title, e.count, e.how_to_fix ] },
                  widths: [ 10, 10, 18, 50, 10, 80 ])
      table_sheet(book, "Hallazgos", Dataset::ISSUE_HEADERS, @dataset.each_issue_row.to_a, widths: [ 10, 10, 18, 26, 40, 60, 50, 60 ])
      table_sheet(book, "Páginas", Dataset::PAGE_HEADERS, @dataset.each_page_row.to_a, widths: [ 60 ] + [ 14 ] * 22)
      table_sheet(book, "Enlaces rotos", [ "Página de origen", "Enlace", "Estado o error", "Tipo" ], @dataset.broken_link_rows, widths: [ 60, 60, 16, 10 ])
      table_sheet(book, "Duplicados", [ "Tipo", "Valor compartido", "URL" ], @dataset.duplicate_rows, widths: [ 14, 60, 60 ])
      table_sheet(book, "Datos estructurados", [ "URL", "Sintaxis", "Tipos", "Sintaxis válida", "Errores" ],
                  @dataset.structured_data_rows, widths: [ 60, 12, 30, 14, 80 ])
      table_sheet(book, "Rendimiento", [
        "URL", "Puntuación", "LCP (ms)", "CLS", "TBT (ms)", "FCP (ms)", "Speed Index (ms)", "TTFB (ms)", "Datos de campo",
        "Categoría de campo", "LCP campo (ms)", "INP campo (ms)", "CLS campo", "Mejora principal", "Error"
      ], @dataset.performance_rows, widths: [ 60 ] + [ 12 ] * 12 + [ 50, 30 ])
      package.to_stream.read
    end

    private
      def summary_sheet(book)
        summary = @dataset.summary
        previous = @crawl.previous_scored
        book.add_worksheet(name: "Resumen") do |sheet|
          sheet.add_row [ "Auditoría SEO de #{@crawl.domain.host}" ], style: @title
          sheet.add_row [ "Fecha", I18n.l(@crawl.finished_at || @crawl.created_at, format: :long) ]
          sheet.add_row [ "URL inicial", @crawl.crawl_config.start_url ]
          sheet.add_row [ "Páginas rastreadas", @crawl.pages_crawled ]
          sheet.add_row [ "Salud del sitio (0–100)", @crawl.health_score ]
          sheet.add_row [ "Crawl anterior", previous&.health_score ] if previous
          sheet.add_row []
          sheet.add_row [ "Categoría", "Puntuación" ], style: @header
          Audit::Scoring::CATEGORY_WEIGHTS.each_key do |category|
            sheet.add_row [ Audit::Scoring::CATEGORY_LABELS[category], @crawl.category_scores[category] ]
          end
          sheet.add_row []
          sheet.add_row [ "Severidad", "Hallazgos" ], style: @header
          summary.by_severity.each { |severity, count| sheet.add_row [ Dataset::SEVERITY_LABELS[severity], count ] }
          sheet.column_widths 30, 50
        end
      end

      def table_sheet(book, name, headers, rows, widths:)
        book.add_worksheet(name:) do |sheet|
          sheet.add_row headers, style: @header
          rows.each { sheet.add_row _1, types: _1.map { |v| v.is_a?(Numeric) ? nil : :string } }
          sheet.sheet_view.pane { |pane| pane.top_left_cell = "A2"; pane.state = :frozen; pane.y_split = 1 }
          sheet.auto_filter = "A1:#{Axlsx.col_ref(headers.size - 1)}#{[ rows.size + 1, 1 ].max}"
          sheet.column_widths(*widths.first(headers.size))
        end
      end
  end
end
