module Audit
  module Checks
    module Indexability
      class Noindex < PageCheck
        define key: "robots.noindex", category: "indexability", severity: "notice", weight: 1

        def evaluate(page) = page.noindex
      end

      class CanonicalMissing < PageCheck
        define key: "canonical.missing", category: "indexability", severity: "notice", weight: 2

        def evaluate(page) = page.canonical_hrefs.empty? && !page.noindex
      end

      # Canonical target that was crawled, if the page points elsewhere.
      module CanonicalTarget
        def target(page)
          page.canonical && page.canonical != page.url ? context.page_by_url(page.canonical) : nil
        end
      end

      class CanonicalToNon200 < PageCheck
        include CanonicalTarget
        define key: "canonical.to_non200", category: "indexability", severity: "error", weight: 7

        def evaluate(page)
          target = target(page)
          target && target.status_code != 200 && { canonical: page.canonical, status: target.status_code }
        end
      end

      class CanonicalToNoindex < PageCheck
        include CanonicalTarget
        define key: "canonical.to_noindex", category: "indexability", severity: "error", weight: 7

        def evaluate(page)
          target = target(page)
          target&.noindex && { canonical: page.canonical }
        end
      end

      class CanonicalMultiple < PageCheck
        define key: "canonical.multiple", category: "indexability", severity: "error", weight: 6

        def evaluate(page) = page.indexability_reason == "canonical_conflict" && { values: page.canonical_hrefs }
      end

      class CanonicalInvalid < PageCheck
        define key: "canonical.relative_or_invalid", category: "indexability", severity: "warning", weight: 3

        def evaluate(page)
          bad = page.canonical_hrefs.reject { _1.match?(%r{\Ahttps?://}i) && Crawling::UrlNormalizer.normalize(_1) }
          bad.any? && { values: bad }
        end
      end

      class CanonicalChain < PageCheck
        include CanonicalTarget
        define key: "canonical.chain", category: "indexability", severity: "warning", weight: 4

        def evaluate(page)
          target = target(page)
          target&.canonical && target.canonical != target.url && { canonical: page.canonical, next: target.canonical }
        end
      end

      class HreflangNoReturn < PageCheck
        define key: "hreflang.no_return", category: "indexability", severity: "warning", weight: 4

        def evaluate(page)
          missing = page.hreflang.filter_map do |entry|
            alternate = entry["href"] != page.url && context.page_by_url(entry["href"])
            next unless alternate && alternate.status_code == 200 && alternate.extracted

            entry["href"] unless alternate.hreflang.any? { _1["href"] == page.url }
          end
          missing.any? && { alternates_without_return: missing.uniq }
        end
      end

      class HreflangInvalidCode < PageCheck
        define key: "hreflang.invalid_code", category: "indexability", severity: "warning", weight: 4

        CODE = /\A([a-z]{2})(-[a-z]{4})?(-([a-z]{2}|\d{3}))?\z/i
        LANGUAGES = %w[
          aa ab ae af ak am an ar as av ay az ba be bg bh bi bm bn bo br bs ca ce ch co cr cs cu cv cy da de dv dz ee el
          en eo es et eu fa ff fi fj fo fr fy ga gd gl gn gu gv ha he hi ho hr ht hu hy hz ia id ie ig ii ik io is it iu
          ja jv ka kg ki kj kk kl km kn ko kr ks ku kv kw ky la lb lg li ln lo lt lu lv mg mh mi mk ml mn mr ms mt my na
          nb nd ne ng nl nn no nr nv ny oc oj om or os pa pi pl ps pt qu rm rn ro ru rw sa sc sd se sg si sk sl sm sn so
          sq sr ss st su sv sw ta te tg th ti tk tl tn to tr ts tt tw ty ug uk ur uz ve vi vo wa wo xh yi yo za zh zu
        ].to_set.freeze

        def evaluate(page)
          invalid = page.hreflang.map { _1["lang"] }.reject { |code| code.casecmp?("x-default") || valid?(code) }
          invalid.any? && { codes: invalid.uniq }
        end

        def valid?(code)
          match = CODE.match(code)
          match && LANGUAGES.include?(match[1].downcase)
        end
      end
    end
  end
end
