module PageSerializer
  LIST_FIELDS = %i[id url depth in_sitemap status_code redirect_url fetch_error content_type content_length truncated
                   response_ms fetched_at title indexable indexability_reason word_count inlinks_count internal_pagerank].freeze
  DETAIL_FIELDS = %i[title_count meta_description meta_description_count meta_robots x_robots_tag noindex nofollow
                     canonical canonical_hrefs lang charset viewport hreflang h1 headings images_count images_missing_alt
                     mixed_content_count mixed_content_samples links_count outlinks_internal outlinks_external open_graph headers].freeze
  MAX_LINKS = 200

  def self.call(page, detail: false)
    data = page.slice(*LIST_FIELDS)
    return data unless detail

    data.merge(page.slice(*DETAIL_FIELDS)).merge(
      structured_data: page.structured_data.map { _1.slice(:syntax, :types, :data, :valid_syntax, :validation_errors, :validation_warnings) },
      issues: page.issues.joins(:check_definition).pluck(:check_key, "check_definitions.severity", "check_definitions.title", :details)
        .map { |key, severity, title, details| { check_key: key, severity:, title:, details: } },
      outlinks: page.links.order(:id).limit(MAX_LINKS).pluck(:to_url, :anchor, :internal, :rel)
        .map { |to_url, anchor, internal, rel| { url: to_url, anchor:, internal:, rel: } },
      inlinks: Link.where(to_page_id: page.id).joins(:from_page).order("pages.id").limit(MAX_LINKS)
        .pluck("pages.url", :anchor).map { |url, anchor| { url:, anchor: } }
    )
  end
end
