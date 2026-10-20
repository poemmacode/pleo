module Audit
  # Health score and issue priority (docs/03 §6, adapted in ADR 0007).
  #
  #   coverage(check)   = 1 for site-wide checks, affected / measured pages for sampled (PageSpeed) checks,
  #                       else min(1, affected pages or URLs / crawled pages)
  #   penalty(check)    = weight × severity factor × √coverage
  #   category score    = 100 × (1 − Σ penalty / Σ weight × factor over the category's checks)
  #   health score      = Σ category score × category weight / 100
  #   priority(finding) = 10 × weight × severity factor × (0.5 × coverage + 0.5 × page importance)
  #
  # Page importance is internal PageRank relative to the crawl's maximum, falling back to inlinks for
  # pages outside the PageRank graph (errors, redirects); findings without a page count as 1.
  # The square root keeps an issue on 1 % of pages from being negligible and one on 100 % from
  # being linear. Notices weigh a quarter so they inform without dominating the score.
  module Scoring
    CATEGORY_WEIGHTS = {
      "crawlability" => 22, "indexability" => 18, "links" => 14, "metadata" => 14, "content" => 10,
      "https" => 6, "structured_data" => 5, "mobile" => 5, "performance" => 3, "ai_search" => 3
    }.freeze
    SEVERITY_FACTORS = { "error" => 1.0, "warning" => 1.0, "notice" => 0.25 }.freeze
    CATEGORY_LABELS = {
      "crawlability" => "Rastreabilidad", "indexability" => "Indexabilidad", "links" => "Enlaces", "metadata" => "Metadatos",
      "content" => "Contenido", "https" => "HTTPS", "structured_data" => "Datos estructurados", "mobile" => "Móvil",
      "performance" => "Rendimiento", "ai_search" => "Búsqueda con IA"
    }.freeze

    module_function

    def call(crawl)
      coverage = coverage_by_check(crawl)
      category_scores = category_scores(coverage)
      health = category_scores.sum { |category, score| score * CATEGORY_WEIGHTS.fetch(category) } / 100.0
      update_priorities(crawl, coverage)
      crawl.update!(health_score: health.round(1), category_scores: category_scores.transform_values { _1.round(1) })
    end

    def coverage_by_check(crawl)
      base = [ crawl.pages.count, 1 ].max
      measured = [ crawl.performance_results.where(error: nil).count, 1 ].max
      checks = Catalog::CHECKS.index_by(&:key)
      crawl.issues.group(:check_key).count.to_h do |key, count|
        check = checks[key]
        coverage = if check&.site_wide? then 1.0
        elsif check&.sampled? then count.to_f / measured
        else count.to_f / base
        end
        [ key, [ coverage, 1.0 ].min ]
      end
    end

    # { category => 0..100 } for every category in the catalog.
    def category_scores(coverage)
      Catalog.definitions.group_by { _1[:category] }.to_h do |category, definitions|
        total = definitions.sum { factor_weight(_1) }
        penalty = definitions.sum { |d| coverage[d[:key]] ? factor_weight(d) * Math.sqrt(coverage[d[:key]]) : 0 }
        [ category, (100 * (1 - penalty / total)).clamp(0, 100) ]
      end
    end

    def factor_weight(definition) = definition[:weight] * SEVERITY_FACTORS.fetch(definition[:severity])

    def update_priorities(crawl, coverage)
      return if coverage.empty?

      definitions = Catalog.definitions.index_by { _1[:key] }
      keys, weights, coverages = coverage.filter_map do |key, cov|
        definition = definitions[key] or next
        [ key, factor_weight(definition).to_f, cov.to_f ]
      end.transpose
      return if keys.nil?

      encoder = PG::TextEncoder::Array.new
      binds = [ crawl.id, encoder.encode(keys), encoder.encode(weights), encoder.encode(coverages) ]
      Issue.connection.exec_update(<<~SQL.squish, "Audit::Scoring priorities", binds)
        WITH maxima AS (
          SELECT MAX(internal_pagerank) AS max_rank, MAX(inlinks_count) AS max_inlinks FROM pages WHERE crawl_id = $1
        ), importance AS (
          SELECT pages.id,
                 CASE WHEN pages.internal_pagerank IS NOT NULL AND maxima.max_rank > 0 THEN pages.internal_pagerank / maxima.max_rank
                      WHEN maxima.max_inlinks > 0 THEN pages.inlinks_count::float / maxima.max_inlinks
                      ELSE 0 END AS value
          FROM pages, maxima WHERE pages.crawl_id = $1
        ), checks AS (
          SELECT * FROM unnest($2::text[], $3::float8[], $4::float8[]) AS c(key, weight, coverage)
        )
        UPDATE issues SET priority_score = ROUND(
          (10 * checks.weight * (0.5 * checks.coverage + 0.5 * COALESCE(importance.value, 1)))::numeric, 1)
        FROM checks, issues AS target LEFT JOIN importance ON importance.id = target.page_id
        WHERE target.id = issues.id AND issues.crawl_id = $1 AND issues.check_key = checks.key
      SQL
    end
  end
end
