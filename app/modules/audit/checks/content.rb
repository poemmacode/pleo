module Audit
  module Checks
    module Content
      class H1Missing < PageCheck
        define key: "h1.missing", category: "content", severity: "warning", weight: 4

        def evaluate(page) = page.h1.empty?
      end

      class H1Multiple < PageCheck
        define key: "h1.multiple", category: "content", severity: "notice", weight: 1

        def evaluate(page) = page.h1.size > 1 && { count: page.h1.size }
      end

      class HeadingsSkipped < PageCheck
        define key: "headings.skipped_level", category: "content", severity: "notice", weight: 1

        def evaluate(page)
          levels = page.headings.map { _1["level"] }
          skips = levels.each_cons(2).select { |a, b| b > a + 1 }
          skips.any? && { skips: skips.first(5).map { |a, b| "H#{a} → H#{b}" } }
        end
      end

      class H1EqualsTitle < PageCheck
        define key: "h1.equals_title", category: "content", severity: "notice", weight: 1

        def evaluate(page) = page.title && page.h1.first&.casecmp?(page.title)
      end

      class Thin < PageCheck
        MIN_WORDS = 200
        define key: "content.thin", category: "content", severity: "warning", weight: 3

        def applies?(page) = super && page.indexable
        def evaluate(page) = page.word_count.to_i < MIN_WORDS && { words: page.word_count }
      end

      class NearDuplicate < PageCheck
        MIN_WORDS = 50
        define key: "content.duplicate", category: "content", severity: "warning", weight: 5

        def findings
          candidates = context.indexable_pages.select { _1.text_simhash && _1.word_count.to_i >= MIN_WORDS }
          @groups = NearDuplicates.groups(candidates.map { [ _1.id, _1.text_simhash ] })
            .each_with_object({}) { |ids, map| ids.each { map[_1] = ids - [ _1 ] } }
          super
        end

        def evaluate(page)
          others = @groups[page.id]
          others && { count: others.size + 1, others: others.first(10).map { context.page_by_id(_1).url } }
        end
      end

      class ImagesMissingAlt < PageCheck
        define key: "images.missing_alt", category: "content", severity: "warning", weight: 2

        def evaluate(page) = page.images_missing_alt.to_i.positive? && { images: page.images_missing_alt, total: page.images_count }
      end
    end
  end
end
