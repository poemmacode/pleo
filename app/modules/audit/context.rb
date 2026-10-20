module Audit
  # Everything the checks need about one crawl, loaded once. Link-level data stays in SQL (#rows).
  class Context
    PAGE_COLUMNS = %i[
      id url depth in_sitemap status_code redirect_url fetch_error content_type content_length truncated response_ms
      extracted title title_count meta_description meta_description_count noindex nofollow canonical_hrefs canonical
      indexable indexability_reason hreflang h1 headings word_count text_simhash title_hash description_hash
      viewport images_count images_missing_alt mixed_content_count mixed_content_samples links_count
      inlinks_count outlinks_internal outlinks_external internal_pagerank
    ].freeze

    attr_reader :crawl, :pages

    def initialize(crawl)
      @crawl = crawl
      @pages = crawl.pages.select(*PAGE_COLUMNS).order(:id).to_a
    end

    def page_by_url(url) = (@by_url ||= pages.index_by(&:url))[url]

    def page_by_id(id) = (@by_id ||= pages.index_by(&:id))[id]

    def indexable_pages = @indexable_pages ||= pages.select { _1.status_code == 200 && _1.indexable }

    def start_url = crawl.crawl_config.start_url

    # Successful PageSpeed measurement of a page, if it was in the sample.
    def performance(page_id)
      @performance ||= crawl.performance_results.where(error: nil).index_by(&:page_id)
      @performance[page_id]
    end

    def site_facts = crawl.site_facts

    def structured_data(page_id)
      @structured_data ||= PageStructuredDatum.joins(:page).where(pages: { crawl_id: crawl.id })
        .pluck(:page_id, :syntax, :types, :valid_syntax, :validation_errors).group_by(&:first)
      @structured_data.fetch(page_id, [])
    end

    # Runs a read-only query with the crawl id bound to $1.
    def rows(sql)
      Page.connection.select_all(sql.squish, "Audit::Context", [ crawl.id ]).to_a
    end
  end
end
