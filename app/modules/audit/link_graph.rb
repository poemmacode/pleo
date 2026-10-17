module Audit
  # Resolves internal link targets to pages and stores in/out link counts (SQL, no Ruby-side graph).
  module LinkGraph
    module_function

    def build(crawl)
      execute(crawl, <<~SQL)
        UPDATE links SET to_page_id = pages.id
        FROM crawl_urls JOIN pages ON pages.crawl_url_id = crawl_urls.id
        WHERE links.crawl_id = $1 AND crawl_urls.crawl_id = $1 AND crawl_urls.url_hash = links.to_url_hash
      SQL
      execute(crawl, "UPDATE pages SET inlinks_count = 0, outlinks_internal = 0, outlinks_external = 0 WHERE crawl_id = $1")
      execute(crawl, <<~SQL)
        UPDATE pages SET inlinks_count = counts.n
        FROM (
          SELECT to_page_id, COUNT(DISTINCT from_page_id) AS n FROM links
          WHERE crawl_id = $1 AND internal AND to_page_id IS NOT NULL AND to_page_id <> from_page_id
          GROUP BY to_page_id
        ) counts
        WHERE pages.id = counts.to_page_id
      SQL
      execute(crawl, <<~SQL)
        UPDATE pages SET outlinks_internal = counts.internal_n, outlinks_external = counts.external_n
        FROM (
          SELECT from_page_id, COUNT(*) FILTER (WHERE internal) AS internal_n, COUNT(*) FILTER (WHERE NOT internal) AS external_n
          FROM links WHERE crawl_id = $1 GROUP BY from_page_id
        ) counts
        WHERE pages.id = counts.from_page_id
      SQL
    end

    def execute(crawl, sql)
      Page.connection.exec_update(sql.squish, "Audit::LinkGraph", [ crawl.id ])
    end
  end
end
