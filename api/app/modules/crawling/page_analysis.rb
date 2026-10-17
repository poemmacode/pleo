module Crawling
  # Stores the extracted on-page fields and validated structured data for a page.
  # Used when a page is fetched and when re-analysing stored HTML (audit:reextract).
  module PageAnalysis
    module_function

    def apply(page, html, headers)
      result = PageExtractor.extract(html, url: page.url, headers:)
      page.update!(result.attributes)
      page.structured_data.delete_all
      rows = result.structured_data.map do |item|
        errors, warnings = item[:valid_syntax] ? Audit::SchemaValidator.validate(item[:data]) : [ [], [] ]
        item.merge(page_id: page.id, validation_errors: item[:validation_errors] + errors, validation_warnings: warnings)
      end
      PageStructuredDatum.insert_all(rows) if rows.any?
      page
    end

    # Pages without HTML to analyse still get an indexability verdict.
    def unanalysable_reason(page)
      return "fetch_error" if page.fetch_error
      return "status_#{page.status_code}" unless page.status_code == 200

      "non_html"
    end

    def reextract(crawl)
      crawl.pages.includes(:page_body).find_each do |page|
        page.page_body ? apply(page, page.body, page.headers) : page.update!(indexable: false, indexability_reason: unanalysable_reason(page))
      end
    end
  end
end
