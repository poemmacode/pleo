module Reports
  # Full audit workbook: summary, problems, findings, pages, broken links, duplicates, structured data
  # and performance, one sheet each, with frozen header rows and filters. Labels follow the current locale.
  class Workbook
    PERFORMANCE_COLUMNS = %i[
      url score lcp_ms cls tbt_ms fcp_ms speed_index_ms ttfb_ms field_scope field_category field_lcp_ms field_inp_ms
      field_cls top_opportunity error
    ].freeze

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
      table_sheet(book, :problems, Dataset.headers(%i[priority severity category problem findings how_to_fix]),
                  @dataset.summary.entries.map { |e| [ e.priority, @dataset.severity(e.severity), @dataset.category(e.category), e.title, e.count, e.how_to_fix ] },
                  widths: [ 10, 10, 18, 50, 10, 80 ])
      table_sheet(book, :findings, @dataset.issue_headers, @dataset.each_issue_row.to_a, widths: [ 10, 10, 18, 26, 40, 60, 50, 60 ])
      table_sheet(book, :pages, @dataset.page_headers, @dataset.each_page_row.to_a, widths: [ 60 ] + [ 14 ] * 22)
      table_sheet(book, :broken_links, Dataset.headers(%i[source_page link status_or_error link_type]), @dataset.broken_link_rows,
                  widths: [ 60, 60, 16, 10 ])
      table_sheet(book, :duplicates, Dataset.headers(%i[duplicate_type shared_value url]), @dataset.duplicate_rows, widths: [ 14, 60, 60 ])
      table_sheet(book, :structured_data, Dataset.headers(%i[url syntax types valid_syntax errors]),
                  @dataset.structured_data_rows, widths: [ 60, 12, 30, 14, 80 ])
      table_sheet(book, :performance, Dataset.headers(PERFORMANCE_COLUMNS), @dataset.performance_rows, widths: [ 60 ] + [ 12 ] * 12 + [ 50, 30 ])
      package.to_stream.read
    end

    private
      def t(key, **options) = I18n.t("reports.workbook.#{key}", **options)

      def summary_sheet(book)
        summary = @dataset.summary
        previous = @crawl.previous_scored
        book.add_worksheet(name: t("sheets.summary")) do |sheet|
          sheet.add_row [ t("title", host: @crawl.domain.host) ], style: @title
          sheet.add_row [ t("date"), I18n.l(@crawl.finished_at || @crawl.created_at, format: :long) ]
          sheet.add_row [ t("start_url"), @crawl.crawl_config.start_url ]
          sheet.add_row [ t("pages_crawled"), @crawl.pages_crawled ]
          sheet.add_row [ t("health"), @crawl.health_score ]
          sheet.add_row [ t("previous_crawl"), previous&.health_score ] if previous
          sheet.add_row []
          sheet.add_row [ I18n.t("reports.columns.category"), I18n.t("reports.columns.score") ], style: @header
          Audit::Scoring::CATEGORY_WEIGHTS.each_key do |category|
            sheet.add_row [ @dataset.category(category), @crawl.category_scores[category] ]
          end
          sheet.add_row []
          sheet.add_row [ I18n.t("reports.columns.severity"), I18n.t("reports.columns.findings") ], style: @header
          summary.by_severity.each { |severity, count| sheet.add_row [ @dataset.severity(severity), count ] }
          sheet.column_widths 30, 50
        end
      end

      def table_sheet(book, name, headers, rows, widths:)
        book.add_worksheet(name: t("sheets.#{name}")) do |sheet|
          sheet.add_row headers, style: @header
          rows.each { sheet.add_row _1, types: _1.map { |v| v.is_a?(Numeric) ? nil : :string } }
          sheet.sheet_view.pane { |pane| pane.top_left_cell = "A2"; pane.state = :frozen; pane.y_split = 1 }
          sheet.auto_filter = "A1:#{Axlsx.col_ref(headers.size - 1)}#{[ rows.size + 1, 1 ].max}"
          sheet.column_widths(*widths.first(headers.size))
        end
      end
  end
end
