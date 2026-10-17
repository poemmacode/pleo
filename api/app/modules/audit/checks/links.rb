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
        define key: "links.internal_broken", category: "links", severity: "error", weight: 9,
          title: "Enlaces internos rotos",
          description: "La página enlaza a URLs internas que devuelven error o no responden.",
          fix: "Actualiza los enlaces a la URL correcta o elimínalos."

        def query = grouped("links.internal AND (target.status_code >= 400 OR target.fetch_error IS NOT NULL)", "JOIN pages target ON target.id = links.to_page_id")
      end

      class ExternalBroken < LinkQueryCheck
        define key: "links.external_broken", category: "links", severity: "warning", weight: 3,
          title: "Enlaces externos rotos",
          description: "Enlaces a otros sitios que devuelven error o no responden; empeoran la experiencia y la confianza.",
          fix: "Sustituye el enlace por uno vigente (o una copia archivada) o elimínalo."

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
        define key: "links.internal_nofollow", category: "links", severity: "warning", weight: 3,
          title: "Enlaces internos con nofollow",
          description: "nofollow en enlaces internos impide que la autoridad fluya hacia tus propias páginas.",
          fix: "Quita rel=\"nofollow\" de los enlaces internos (salvo casos como login o carrito)."

        def query = grouped("links.internal AND 'nofollow' = ANY(links.rel)")
      end

      class ToRedirect < LinkQueryCheck
        define key: "links.to_redirect", category: "links", severity: "notice", weight: 2,
          title: "Enlaces internos a redirecciones",
          description: "Enlazar a una URL que redirige añade un salto innecesario.",
          fix: "Enlaza directamente a la URL de destino."

        def query = grouped("links.internal AND target.status_code BETWEEN 300 AND 399", "JOIN pages target ON target.id = links.to_page_id")
      end

      class TooMany < PageCheck
        LIMIT = 300
        define key: "links.too_many", category: "links", severity: "notice", weight: 1,
          title: "Demasiados enlaces en la página",
          description: "Más de 300 enlaces diluyen la autoridad y dificultan entender qué es importante.",
          fix: "Reduce menús y bloques de enlaces repetidos; prioriza los relevantes."

        def evaluate(page) = page.links_count.to_i > LIMIT && { links: page.links_count }
      end
    end
  end
end
