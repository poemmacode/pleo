module Audit
  module Checks
    module Metadata
      # Indexable pages sharing a hash, e.g. the same title. Returns { page_id => [other urls] }.
      module Duplicates
        def duplicates_by(attribute)
          context.indexable_pages.select { _1.public_send(attribute) }.group_by { _1.public_send(attribute) }.values
            .select { _1.size > 1 }
            .each_with_object({}) { |group, map| group.each { |page| map[page.id] = (group - [ page ]).map(&:url) } }
        end

        def duplicate_details(others) = { count: others.size + 1, others: others.first(10) }
      end

      class TitleMissing < PageCheck
        define key: "title.missing", category: "metadata", severity: "error", weight: 8

        def evaluate(page) = page.title.nil?
      end

      class TitleDuplicate < PageCheck
        include Duplicates
        define key: "title.duplicate", category: "metadata", severity: "error", weight: 6

        def findings
          @duplicates = duplicates_by(:title_hash)
          super
        end

        def evaluate(page) = @duplicates[page.id]&.then { duplicate_details(_1) }
      end

      class TitleTooLong < PageCheck
        define key: "title.too_long", category: "metadata", severity: "warning", weight: 2

        def evaluate(page) = page.title && page.title.length > 60 && { length: page.title.length }
      end

      class TitleTooShort < PageCheck
        define key: "title.too_short", category: "metadata", severity: "notice", weight: 1

        def evaluate(page) = page.title && page.title.length < 15 && { length: page.title.length }
      end

      class TitleMultiple < PageCheck
        define key: "title.multiple", category: "metadata", severity: "warning", weight: 3

        def evaluate(page) = page.title_count.to_i > 1 && { count: page.title_count }
      end

      class DescriptionMissing < PageCheck
        define key: "meta_description.missing", category: "metadata", severity: "warning", weight: 3

        def applies?(page) = super && page.indexable
        def evaluate(page) = page.meta_description.nil?
      end

      class DescriptionDuplicate < PageCheck
        include Duplicates
        define key: "meta_description.duplicate", category: "metadata", severity: "warning", weight: 4

        def findings
          @duplicates = duplicates_by(:description_hash)
          super
        end

        def evaluate(page) = @duplicates[page.id]&.then { duplicate_details(_1) }
      end

      class DescriptionLength < PageCheck
        define key: "meta_description.length", category: "metadata", severity: "notice", weight: 1

        def evaluate(page)
          length = page.meta_description&.length
          length && !(70..160).cover?(length) && { length: }
        end
      end
    end
  end
end
