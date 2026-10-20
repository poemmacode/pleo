module Audit
  module Checks
    module Crawlability
      class Http4xx < PageCheck
        define key: "http.4xx", category: "crawlability", severity: "error", weight: 9,
          title: "Páginas con error 4xx",
          description: "La URL responde con un error de cliente (por ejemplo 404). Usuarios y buscadores llegan a una página que no existe.",
          fix: "Restaura la página, redirígela (301) a la URL equivalente o elimina los enlaces y entradas de sitemap que apuntan a ella."

        def applies?(page) = page.status_code.present?
        def evaluate(page) = (400..499).cover?(page.status_code) && { status: page.status_code }
      end

      class Http5xx < PageCheck
        define key: "http.5xx", category: "crawlability", severity: "error", weight: 10,
          title: "Páginas con error 5xx",
          description: "El servidor falló al servir la página. Si se repite, los buscadores reducen el rastreo y pueden desindexarla.",
          fix: "Revisa los logs del servidor para esa URL y corrige el error; comprueba también la capacidad del servidor."

        def applies?(page) = page.status_code.present?
        def evaluate(page) = (500..599).cover?(page.status_code) && { status: page.status_code }
      end

      class FetchFailed < PageCheck
        define key: "http.timeout", category: "crawlability", severity: "error", weight: 7,
          title: "Páginas que no respondieron",
          description: "No se obtuvo respuesta HTTP (tiempo agotado o conexión rechazada).",
          fix: "Comprueba que la página carga y que el servidor no bloquea ni limita en exceso a los rastreadores."

        def applies?(page) = page.fetch_error.present?
        def evaluate(page) = !page.fetch_error.start_with?("Tls") && { error: page.fetch_error }
      end

      # Follows redirect_url through crawled pages to detect chains and loops.
      module RedirectPaths
        MAX_HOPS = 10

        def path_from(page)
          path = [ page.url ]
          current = page
          while current&.redirect_url && path.size <= MAX_HOPS
            return [ path + [ current.redirect_url ], true ] if path.include?(current.redirect_url)

            path << current.redirect_url
            current = context.page_by_url(current.redirect_url)
          end
          [ path, false ]
        end
      end

      class RedirectChain < PageCheck
        include RedirectPaths
        define key: "redirect.chain", category: "crawlability", severity: "warning", weight: 4,
          title: "Cadenas de redirecciones",
          description: "La URL redirige a otra que a su vez redirige. Cada salto añade latencia y desperdicia presupuesto de rastreo.",
          fix: "Haz que la primera URL redirija directamente al destino final y actualiza los enlaces internos."

        def applies?(page) = page.redirect_url.present?

        def evaluate(page)
          path, loop = path_from(page)
          !loop && path.size > 2 && { hops: path.size - 1, path: }
        end
      end

      class RedirectLoop < PageCheck
        include RedirectPaths
        define key: "redirect.loop", category: "crawlability", severity: "error", weight: 8,
          title: "Bucles de redirección",
          description: "Las redirecciones vuelven a una URL ya visitada; la página nunca llega a cargar.",
          fix: "Revisa las reglas de redirección (servidor, CMS, CDN) para que terminen en una URL que responda 200."

        def applies?(page) = page.redirect_url.present?

        def evaluate(page)
          path, loop = path_from(page)
          loop && { path: }
        end
      end

      class RedirectTemporary < PageCheck
        define key: "redirect.temporary", category: "crawlability", severity: "notice", weight: 2,
          title: "Redirecciones temporales enlazadas",
          description: "Enlaces internos llevan a una redirección 302/307. Los buscadores pueden seguir indexando la URL original.",
          fix: "Si el cambio es permanente usa 301/308 y enlaza directamente a la URL final."

        def applies?(page) = [ 302, 307 ].include?(page.status_code)
        def evaluate(page) = page.inlinks_count.positive? && { status: page.status_code, target: page.redirect_url }
      end

      class RobotsBlockedLinked < Check
        define key: "robots.blocked_internal_linked", category: "crawlability", severity: "warning", weight: 4,
          title: "URLs enlazadas bloqueadas por robots.txt",
          description: "Hay enlaces internos hacia URLs que robots.txt prohíbe rastrear. Pueden aparecer en resultados sin descripción.",
          fix: "Si la URL debe posicionar, permítela en robots.txt; si no, elimina o cambia los enlaces internos."

        def findings
          context.rows(<<~SQL).map { site_finding({ linked_from_pages: _1["pages"] }, url: _1["url"]) }
            SELECT crawl_urls.url, COUNT(DISTINCT links.from_page_id) AS pages
            FROM crawl_urls JOIN links ON links.crawl_id = crawl_urls.crawl_id AND links.to_url_hash = crawl_urls.url_hash AND links.internal
            WHERE crawl_urls.crawl_id = $1 AND crawl_urls.skip_reason = 'robots'
            GROUP BY crawl_urls.url ORDER BY crawl_urls.url
          SQL
        end
      end

      class SitemapNon200 < PageCheck
        define key: "sitemap.non_200", category: "crawlability", severity: "warning", weight: 5,
          title: "URLs del sitemap que no responden 200",
          description: "El sitemap debe listar solo URLs canónicas que respondan 200; las demás confunden a los buscadores.",
          fix: "Quita del sitemap las URLs con redirección o error, o sustitúyelas por su destino final."

        def applies?(page) = page.in_sitemap
        def evaluate(page) = page.status_code != 200 && { status: page.status_code, error: page.fetch_error }.compact
      end

      class SitemapNoindex < PageCheck
        define key: "sitemap.noindex", category: "crawlability", severity: "warning", weight: 5,
          title: "URLs del sitemap no indexables",
          description: "El sitemap incluye páginas con noindex o con canonical hacia otra URL: señales contradictorias.",
          fix: "Elimina esas URLs del sitemap o haz que sean indexables."

        def applies?(page) = page.in_sitemap && super
        def evaluate(page) = !page.indexable && { reason: page.indexability_reason }
      end

      class SitemapMissing < Check
        site_wide!
        define key: "sitemap.missing", category: "crawlability", severity: "warning", weight: 3,
          title: "No se encontró sitemap",
          description: "Ni robots.txt declara un sitemap ni existe /sitemap.xml. El sitemap ayuda a descubrir páginas nuevas o poco enlazadas.",
          fix: "Publica un sitemap XML con las URLs canónicas y declara su ubicación en robots.txt (línea Sitemap:)."

        def findings
          crawl = context.crawl
          return [] unless crawl.sitemap_status == "done"
          return [] if crawl.sitemaps.any? { _1["status"] == 200 }

          [ site_finding({ tried: crawl.sitemaps.map { _1["url"] } }) ]
        end
      end

      class Orphan < PageCheck
        define key: "page.orphan", category: "crawlability", severity: "warning", weight: 4,
          title: "Páginas huérfanas",
          description: "Están en el sitemap pero ninguna página rastreada las enlaza; reciben poca autoridad interna.",
          fix: "Enlázalas desde páginas relevantes (menús, categorías, artículos relacionados) o retíralas si sobran."

        def applies?(page) = page.in_sitemap && super
        def evaluate(page) = page.inlinks_count.zero? && page.url != context.start_url
      end

      class Deep < PageCheck
        define key: "page.deep", category: "crawlability", severity: "notice", weight: 2,
          title: "Páginas a más de 4 clics de la portada",
          description: "Cuanto más profunda está una página, menos se rastrea y menos autoridad recibe.",
          fix: "Acorta el camino: enlaces desde categorías o la portada, paginación más plana o enlaces relacionados."

        def evaluate(page) = page.depth.to_i > 4 && { depth: page.depth }
      end
    end
  end
end
