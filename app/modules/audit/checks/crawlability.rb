module Audit
  module Checks
    module Crawlability
      class Http4xx < PageCheck
        define key: "http.4xx", category: "crawlability", severity: "error", weight: 9

        def applies?(page) = page.status_code.present?
        def evaluate(page) = (400..499).cover?(page.status_code) && { status: page.status_code }
      end

      class Http5xx < PageCheck
        define key: "http.5xx", category: "crawlability", severity: "error", weight: 10

        def applies?(page) = page.status_code.present?
        def evaluate(page) = (500..599).cover?(page.status_code) && { status: page.status_code }
      end

      class FetchFailed < PageCheck
        define key: "http.timeout", category: "crawlability", severity: "error", weight: 7

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
        define key: "redirect.chain", category: "crawlability", severity: "warning", weight: 4

        def applies?(page) = page.redirect_url.present?

        def evaluate(page)
          path, loop = path_from(page)
          !loop && path.size > 2 && { hops: path.size - 1, path: }
        end
      end

      class RedirectLoop < PageCheck
        include RedirectPaths
        define key: "redirect.loop", category: "crawlability", severity: "error", weight: 8

        def applies?(page) = page.redirect_url.present?

        def evaluate(page)
          path, loop = path_from(page)
          loop && { path: }
        end
      end

      class RedirectTemporary < PageCheck
        define key: "redirect.temporary", category: "crawlability", severity: "notice", weight: 2

        def applies?(page) = [ 302, 307 ].include?(page.status_code)
        def evaluate(page) = page.inlinks_count.positive? && { status: page.status_code, target: page.redirect_url }
      end

      class RobotsBlockedLinked < Check
        define key: "robots.blocked_internal_linked", category: "crawlability", severity: "warning", weight: 4

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
        define key: "sitemap.non_200", category: "crawlability", severity: "warning", weight: 5

        def applies?(page) = page.in_sitemap
        def evaluate(page) = page.status_code != 200 && { status: page.status_code, error: page.fetch_error }.compact
      end

      class SitemapNoindex < PageCheck
        define key: "sitemap.noindex", category: "crawlability", severity: "warning", weight: 5

        def applies?(page) = page.in_sitemap && super
        def evaluate(page) = !page.indexable && { reason: page.indexability_reason }
      end

      class SitemapMissing < Check
        site_wide!
        define key: "sitemap.missing", category: "crawlability", severity: "warning", weight: 3

        def findings
          crawl = context.crawl
          return [] unless crawl.sitemap_status == "done"
          return [] if crawl.sitemaps.any? { _1["status"] == 200 }

          [ site_finding({ tried: crawl.sitemaps.map { _1["url"] } }) ]
        end
      end

      class Orphan < PageCheck
        define key: "page.orphan", category: "crawlability", severity: "warning", weight: 4

        def applies?(page) = page.in_sitemap && super
        def evaluate(page) = page.inlinks_count.zero? && page.url != context.start_url
      end

      class Deep < PageCheck
        define key: "page.deep", category: "crawlability", severity: "notice", weight: 2

        def evaluate(page) = page.depth.to_i > 4 && { depth: page.depth }
      end
    end
  end
end
