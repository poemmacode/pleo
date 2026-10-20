module Audit
  module Checks
    module Links
      # Link checks run in SQL: one row per source page with sample target URLs.
      class LinkQueryCheck < Check
        def findings
          context.rows(query).map do |row|
            Finding.new(row["page_id"], row["url"], { count: row["n"], targets: PG::TextDecoder::Array.new.decode(row["targets"]).first(10) })
          end
        end

        def grouped(condition, joins = "")
          <<~SQL
            SELECT pages.id AS page_id, pages.url, COUNT(*) AS n, (array_agg(DISTINCT links.to_url))[1:10] AS targets
            FROM links JOIN pages ON pages.id = links.from_page_id #{joins}
            WHERE links.crawl_id = $1 AND #{condition}
            GROUP BY pages.id, pages.url ORDER BY pages.id
          SQL
        end
      end

      class InternalBroken < LinkQueryCheck
        define key: "links.internal_broken", category: "links", severity: "error", weight: 9

        def query = grouped("links.internal AND (target.status_code >= 400 OR target.fetch_error IS NOT NULL)", "JOIN pages target ON target.id = links.to_page_id")
      end

      class ExternalBroken < LinkQueryCheck
        define key: "links.external_broken", category: "links", severity: "warning", weight: 3

        def query
          grouped(<<~SQL, "JOIN external_link_checks c ON c.crawl_id = links.crawl_id AND c.url_hash = links.to_url_hash")
            NOT links.internal AND (
              (c.status_code BETWEEN 400 AND 599 AND c.status_code <> 429)
              OR c.error IN ('connection', 'timeout', 'resolution', 'tls', 'too_many_redirects')
            )
          SQL
        end
      end

      class InternalNofollow < LinkQueryCheck
        define key: "links.internal_nofollow", category: "links", severity: "warning", weight: 3

        def query = grouped("links.internal AND 'nofollow' = ANY(links.rel)")
      end

      class ToRedirect < LinkQueryCheck
        define key: "links.to_redirect", category: "links", severity: "notice", weight: 2

        def query = grouped("links.internal AND target.status_code BETWEEN 300 AND 399", "JOIN pages target ON target.id = links.to_page_id")
      end

      class TooMany < PageCheck
        LIMIT = 300
        define key: "links.too_many", category: "links", severity: "notice", weight: 1

        def evaluate(page) = page.links_count.to_i > LIMIT && { links: page.links_count }
      end
    end
  end
end
