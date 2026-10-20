module Reports
  # One-to-three page PDF for stakeholders: health score, categories, top problems with how to fix
  # them, performance highlights and crawl figures. Uses Prawn's built-in fonts (no network, no
  # bundled font files), so text is limited to Windows-1252; other characters become "?".
  class ExecutiveSummary
    TOP_PROBLEMS = 10
    # Common symbols outside Windows-1252 and a readable ASCII stand-in.
    TRANSLITERATIONS = { "→" => "->", "←" => "<-", "≥" => ">=", "≤" => "<=", "−" => "-", "▲" => "+", "▼" => "-", "≈" => "~" }.freeze
    MIN_SECTION_SPACE = 120
    ACCENT = "2456D6"
    MUTED = "62656D"

    def initialize(crawl)
      @crawl = crawl
      @dataset = Dataset.new(crawl)
    end

    def render
      pdf = Prawn::Document.new(page_size: "A4", margin: 48, info: { Title: text("Auditoría SEO de #{@crawl.domain.host}"), Creator: "SEO Platform" })
      # Without kerning each line is written as one string, which keeps the PDF's text searchable.
      pdf.default_kerning(false)
      header(pdf)
      health(pdf)
      problems(pdf)
      performance(pdf)
      crawl_figures(pdf)
      pdf.number_pages text("Página <page> de <total> · generado el #{I18n.l(Time.current, format: :long)}"),
                       at: [ pdf.bounds.left, -10 ], size: 8, color: MUTED
      pdf.render
    end

    private
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

      def header(pdf)
        pdf.text text("Auditoría SEO"), size: 22, style: :bold, color: ACCENT
        pdf.text text(@crawl.domain.host), size: 14
        pdf.text text("Crawl del #{I18n.l(@crawl.finished_at || @crawl.created_at, format: :long)} · #{@crawl.pages_crawled} páginas"),
                 size: 10, color: MUTED
        pdf.move_down 16
      end

      def health(pdf)
        score = @crawl.health_score
        pdf.text text("Salud del sitio: #{score ? format("%.1f", score).tr(".", ",") : "—"} / 100"), size: 18, style: :bold
        previous = @crawl.previous_scored
        if previous && score
          delta = (score - previous.health_score).round(1)
          pdf.text text("#{delta.positive? ? "+" : ""}#{delta.to_s.tr(".", ",")} frente al crawl anterior (#{previous.health_score.to_s.tr(".", ",")})"),
                   size: 10, color: MUTED
        end
        pdf.move_down 8
        rows = Audit::Scoring::CATEGORY_WEIGHTS.keys.filter_map do |category|
          value = @crawl.category_scores[category]
          value && [ text(Audit::Scoring::CATEGORY_LABELS[category]), text(value.to_s.tr(".", ",")) ]
        end
        pdf.table([ [ "Categoría", "Puntuación" ] ] + rows, header: true, width: 300,
                  cell_style: { size: 9, padding: [ 3, 6 ], border_color: "DDDDDD" }) do |table|
          table.row(0).font_style = :bold
          table.row(0).background_color = "E8EEF9"
          table.column(1).align = :right
        end
        counts = @dataset.summary.by_severity
        pdf.move_down 6
        pdf.text text("Hallazgos: #{counts["error"]} errores, #{counts["warning"]} avisos, #{counts["notice"]} notas"), size: 10
        pdf.move_down 16
      end

      def problems(pdf)
        entries = @dataset.summary.entries.first(TOP_PROBLEMS)
        section(pdf, "Qué arreglar primero")
        pdf.text text("Ordenado por prioridad: gravedad, cuántas páginas afecta y lo importantes que son."), size: 9, color: MUTED
        pdf.move_down 6
        return pdf.text(text("No se encontraron problemas."), size: 10) if entries.empty?

        entries.each_with_index do |entry, index|
          pdf.start_new_page if pdf.cursor < 50
          severity = Dataset::SEVERITY_LABELS[entry.severity]
          pdf.text text("#{index + 1}. #{entry.title}"), size: 11, style: :bold
          pdf.text text("#{severity} · #{entry.count} #{entry.count == 1 ? "hallazgo" : "hallazgos"} · prioridad #{entry.priority}"), size: 9, color: MUTED
          pdf.text text(entry.how_to_fix), size: 9
          pdf.move_down 8
        end
        pdf.move_down 8
      end

      def performance(pdf)
        results = @crawl.performance_results.includes(:page).where(error: nil).where.not(performance_score: nil).order(:performance_score)
        return if results.empty?

        average = (results.sum(&:performance_score).to_f / results.size).round
        section(pdf, "Rendimiento móvil (PageSpeed Insights)")
        pdf.text text("Puntuación media de #{results.size} páginas medidas: #{average}/100. Las más lentas:"), size: 10
        pdf.move_down 4
        rows = results.first(5).map do |r|
          [ text(r.page.url), r.performance_score.to_s, text(r.lcp_ms ? "#{(r.lcp_ms / 1000.0).round(1).to_s.tr(".", ",")} s" : "—") ]
        end
        pdf.table([ [ "Página", "Puntuación", "LCP" ] ] + rows, header: true, width: pdf.bounds.width,
                  column_widths: { 1 => 70, 2 => 60 }, cell_style: { size: 8, padding: [ 3, 5 ], border_color: "DDDDDD" }) do |table|
          table.row(0).font_style = :bold
          table.row(0).background_color = "E8EEF9"
        end
        pdf.move_down 16
      end

      def crawl_figures(pdf)
        section(pdf, "Datos del rastreo")
        codes = @crawl.pages.group(:status_code).count.sort_by { |code, _| code || 0 }
          .map { |code, n| "#{code || "sin respuesta"}: #{n}" }.join(", ")
        [
          "URL inicial: #{@crawl.crawl_config.start_url}",
          "URLs descubiertas: #{@crawl.pages_discovered} · rastreadas: #{@crawl.pages_crawled} · omitidas: #{@crawl.pages_skipped}",
          "Códigos HTTP: #{codes.presence || "—"}"
        ].each { pdf.text text(_1), size: 9 }
      end
  end
end
