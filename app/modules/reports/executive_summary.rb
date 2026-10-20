module Reports
  # One-to-three page PDF for stakeholders, in the current locale: health score, categories, top
  # problems with how to fix them, performance highlights and crawl figures. Uses Prawn's built-in
  # fonts (no network, no bundled font files), so text is limited to Windows-1252; common symbols
  # are transliterated and other characters become "?".
  class ExecutiveSummary
    TOP_PROBLEMS = 10
    ACCENT = "2456D6"
    MUTED = "62656D"
    # Common symbols outside Windows-1252 and a readable ASCII stand-in.
    TRANSLITERATIONS = { "→" => "->", "←" => "<-", "≥" => ">=", "≤" => "<=", "−" => "-", "▲" => "+", "▼" => "-", "≈" => "~" }.freeze
    MIN_SECTION_SPACE = 120

    def initialize(crawl)
      @crawl = crawl
      @dataset = Dataset.new(crawl)
    end

    def render
      pdf = Prawn::Document.new(page_size: "A4", margin: 48, info: { Title: text(t("title", host: @crawl.domain.host)), Creator: "SEO Platform" })
      # Without kerning each line is written as one string, which keeps the PDF's text searchable.
      pdf.default_kerning(false)
      header(pdf)
      health(pdf)
      problems(pdf)
      performance(pdf)
      crawl_figures(pdf)
      pdf.number_pages text(t("footer", generated: I18n.l(Time.current, format: :long))),
                       at: [ pdf.bounds.left, -10 ], size: 8, color: MUTED
      pdf.render
    end

    private
      def t(key, **options) = I18n.t("reports.pdf.#{key}", **options)

      def number(value, precision: 1)
        ActiveSupport::NumberHelper.number_to_rounded(value, precision:, strip_insignificant_zeros: true, locale: I18n.locale)
      end

      # Prawn's AFM fonts only cover Windows-1252.
      def text(value)
        value.to_s.gsub(Regexp.union(TRANSLITERATIONS.keys), TRANSLITERATIONS)
          .encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").encode("UTF-8")
      end

      # Starts a section heading on a new page when too little room is left for its content.
      def section(pdf, title)
        pdf.start_new_page if pdf.cursor < MIN_SECTION_SPACE
        pdf.text text(title), size: 14, style: :bold, color: ACCENT
      end

      def table_style(table)
        table.row(0).font_style = :bold
        table.row(0).background_color = "E8EEF9"
      end

      def header(pdf)
        pdf.text text(t("heading")), size: 22, style: :bold, color: ACCENT
        pdf.text text(@crawl.domain.host), size: 14
        pdf.text text(t("subtitle", date: I18n.l(@crawl.finished_at || @crawl.created_at, format: :long), count: @crawl.pages_crawled)),
                 size: 10, color: MUTED
        pdf.move_down 16
      end

      def health(pdf)
        score = @crawl.health_score
        pdf.text text(t("health", score: score ? number(score) : "—")), size: 18, style: :bold
        previous = @crawl.previous_scored
        if previous && score
          delta = (score - previous.health_score).round(1)
          pdf.text text(t("compared_to", delta: "#{delta.positive? ? "+" : ""}#{number(delta)}", previous: number(previous.health_score))),
                   size: 10, color: MUTED
        end
        pdf.move_down 8
        rows = Audit::Scoring::CATEGORY_WEIGHTS.keys.filter_map do |category|
          value = @crawl.category_scores[category]
          value && [ text(@dataset.category(category)), text(number(value)) ]
        end
        headers = [ I18n.t("reports.columns.category"), I18n.t("reports.columns.score") ].map { text(_1) }
        pdf.table([ headers ] + rows, header: true, width: 300, cell_style: { size: 9, padding: [ 3, 6 ], border_color: "DDDDDD" }) do |table|
          table_style(table)
          table.column(1).align = :right
        end
        counts = @dataset.summary.by_severity
        pdf.move_down 6
        pdf.text text(t("findings", errors: counts["error"], warnings: counts["warning"], notices: counts["notice"])), size: 10
        pdf.move_down 16
      end

      def problems(pdf)
        entries = @dataset.summary.entries.first(TOP_PROBLEMS)
        section(pdf, t("fix_first"))
        pdf.text text(t("fix_first_hint")), size: 9, color: MUTED
        pdf.move_down 6
        return pdf.text(text(t("no_problems")), size: 10) if entries.empty?

        entries.each_with_index do |entry, index|
          pdf.start_new_page if pdf.cursor < 50
          pdf.text text("#{index + 1}. #{entry.title}"), size: 11, style: :bold
          pdf.text text(t("problem_meta", severity: @dataset.severity(entry.severity), findings: t("findings_count", count: entry.count),
                          priority: entry.priority)), size: 9, color: MUTED
          pdf.text text(entry.how_to_fix), size: 9
          pdf.move_down 8
        end
        pdf.move_down 8
      end

      def performance(pdf)
        results = @crawl.performance_results.includes(:page).where(error: nil).where.not(performance_score: nil).order(:performance_score)
        return if results.empty?

        average = (results.sum(&:performance_score).to_f / results.size).round
        section(pdf, t("performance"))
        pdf.text text(t("performance_average", count: results.size, average:)), size: 10
        pdf.move_down 4
        rows = results.first(5).map do |r|
          [ text(r.page.url), r.performance_score.to_s, text(r.lcp_ms ? "#{number(r.lcp_ms / 1000.0)} s" : "—") ]
        end
        headers = [ I18n.t("reports.columns.page"), I18n.t("reports.columns.score"), "LCP" ].map { text(_1) }
        pdf.table([ headers ] + rows, header: true, width: pdf.bounds.width,
                  column_widths: { 1 => 70, 2 => 60 }, cell_style: { size: 8, padding: [ 3, 5 ], border_color: "DDDDDD" }) do |table|
          table_style(table)
        end
        pdf.move_down 16
      end

      def crawl_figures(pdf)
        section(pdf, t("crawl_data"))
        codes = @crawl.pages.group(:status_code).count.sort_by { |code, _| code || 0 }
          .map { |code, n| "#{code || I18n.t("crawls.progress.no_response")}: #{n}" }.join(", ")
        [
          t("start_url", url: @crawl.crawl_config.start_url),
          t("url_counts", discovered: @crawl.pages_discovered, crawled: @crawl.pages_crawled, skipped: @crawl.pages_skipped),
          t("status_codes", codes: codes.presence || "—")
        ].each { pdf.text text(_1), size: 9 }
      end
  end
end
