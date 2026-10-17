module Audit
  # A check evaluated page by page. `evaluate` returns nil (no problem), true or a details hash.
  class PageCheck < Check
    def findings
      context.pages.filter_map do |page|
        next unless applies?(page)

        result = evaluate(page)
        finding(page, result == true ? {} : result) if result
      end
    end

    # By default, only successfully fetched HTML pages that were analysed.
    def applies?(page) = page.status_code == 200 && page.extracted

    def evaluate(_page)
      raise NotImplementedError
    end
  end
end
