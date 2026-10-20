module Reports
  # Rows shared by the CSV, Excel and PDF reports, labelled in the current locale.
  # Text cells go through Reports.safe_cell.
  class Dataset
    PAGE_COLUMNS = %i[
      url status error redirect indexable not_indexable_reason depth in_sitemap title title_length meta_description
      description_length h1 canonical meta_robots words inlinks internal_outlinks external_outlinks pagerank response_ms
      bytes content_type
    ].freeze
    ISSUE_COLUMNS = %i[priority severity category check problem url details how_to_fix].freeze
    BATCH = 2_000

    attr_reader :crawl

    def initialize(crawl)
      @crawl = crawl
    end

    def self.headers(columns) = columns.map { I18n.t("reports.columns.#{_1}") }

    def page_headers = self.class.headers(PAGE_COLUMNS)

    def issue_headers = self.class.headers(ISSUE_COLUMNS)

    def severity(value) = value && I18n.t("audit.severities.#{value}")

    def category(value) = value && I18n.t("audit.categories.#{value}")

    def each_page_row
      return enum_for(:each_page_row) unless block_given?

      crawl.pages.order(:id).in_batches(of: BATCH) do |batch|
        batch.order(:id).each do |page|
          yield safe([
            page.url, page.status_code, page.fetch_error, page.redirect_url, yes_no(page.indexable), page.indexability_reason,
            page.depth, yes_no(page.in_sitemap), page.title, page.title&.length, page.meta_description,
            page.meta_description&.length, page.h1.first, page.canonical, page.meta_robots, page.word_count,
            page.inlinks_count, page.outlinks_internal, page.outlinks_external, page.internal_pagerank&.round(6),
            page.response_ms, page.content_length, page.content_type
          ])
        end
      end
    end

    # Every finding, highest priority first.
    def each_issue_row
      return enum_for(:each_issue_row) unless block_given?

      definitions = CheckDefinition.all.index_by(&:key)
      crawl.issues.order(Arel.sql("priority_score DESC NULLS LAST, id"))
        .pluck(:priority_score, :check_key, :url, :details).each do |priority, key, url, details|
          definition = definitions[key]
          yield safe([
            priority, severity(definition&.severity), category(definition&.category), key, definition&.title,
            url || I18n.t("reports.whole_site"), details_text(details), definition&.how_to_fix
          ])
        end
    end

    def summary = @summary ||= Audit::Summary.new(crawl)

    # [source URL, target URL, status or error, internal/external]
    def broken_link_rows
      internal = Link.where(crawl_id: crawl.id, internal: true).joins("JOIN pages target ON target.id = links.to_page_id")
        .joins(:from_page).where("target.status_code >= 400 OR target.fetch_error IS NOT NULL")
        .pluck("pages.url", :to_url, Arel.sql("COALESCE(target.status_code::text, target.fetch_error)"))
        .map { [ *_1, I18n.t("reports.internal") ] }
      external = Link.where(crawl_id: crawl.id, internal: false)
        .joins("JOIN external_link_checks c ON c.crawl_id = links.crawl_id AND c.url_hash = links.to_url_hash")
        .joins(:from_page)
        .where("(c.status_code BETWEEN 400 AND 599 AND c.status_code <> 429) OR c.error IN ('connection', 'timeout', 'resolution', 'tls', 'too_many_redirects')")
        .pluck("pages.url", :to_url, Arel.sql("COALESCE(c.status_code::text, c.error)"))
        .map { [ *_1, I18n.t("reports.external") ] }
      (internal + external).map { safe(_1) }
    end

    # [type, shared value, URL]
    def duplicate_rows
      Audit::Duplicates::TYPES.flat_map do |type|
        label = I18n.t("crawls.duplicates.index.types.#{type}")
        Audit::Duplicates.groups(crawl, type).flat_map do |pages|
          value = Audit::Duplicates.label(type, pages)
          pages.map { safe([ label, value, _1.url ]) }
        end
      end
    end

    def structured_data_rows
      PageStructuredDatum.joins(:page).where(pages: { crawl_id: crawl.id }).order("pages.id")
        .pluck("pages.url", :syntax, :types, :valid_syntax, :validation_errors).map do |url, syntax, types, valid, errors|
          safe([ url, syntax, types.join(", "), yes_no(valid), errors.map { _1.is_a?(Hash) ? _1.values.join(" · ") : _1 }.join(" | ") ])
        end
    end

    def performance_rows
      crawl.performance_results.includes(:page).order(:performance_score).map do |r|
        safe([ r.page.url, r.performance_score, r.lcp_ms, r.cls, r.tbt_ms, r.fcp_ms, r.speed_index_ms, r.ttfb_ms,
               r.field_scope, r.field_category, r.field_lcp_ms, r.field_inp_ms, r.field_cls,
               r.opportunities.first&.dig("title"), r.error ])
      end
    end

    def details_text(details)
      details.map { |key, value| "#{key}: #{Array(value).first(5).join(", ")}" }.join(" · ")
    end

    private
      def safe(row) = row.map { Reports.safe_cell(_1) }

      def yes_no(value) = value.nil? ? nil : I18n.t(value ? "common.yes" : "common.no")
  end
end
