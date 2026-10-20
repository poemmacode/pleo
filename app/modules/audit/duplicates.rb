module Audit
  # Groups of indexable pages sharing a title or description, or with near-identical text
  # (duplicates view and reports).
  module Duplicates
    TYPES = { "title" => "Títulos", "description" => "Descripciones", "content" => "Contenido" }.freeze
    MAX_GROUPS = 500

    module_function

    # Arrays of pages, largest groups first.
    def groups(crawl, type)
      pages = crawl.pages.where(indexable: true)
      groups = case type
      when "title" then pages.where.not(title_hash: nil).group_by(&:title_hash).values.select { _1.size > 1 }
      when "description" then pages.where.not(description_hash: nil).group_by(&:description_hash).values.select { _1.size > 1 }
      when "content"
        candidates = pages.where.not(text_simhash: nil).where(word_count: Checks::Content::NearDuplicate::MIN_WORDS..)
        by_id = candidates.index_by(&:id)
        NearDuplicates.groups(candidates.map { [ _1.id, _1.text_simhash ] }).map { |ids| ids.map { by_id[_1] } }
      else raise ArgumentError, "tipo de duplicado desconocido: #{type}"
      end
      groups.sort_by { -_1.size }.first(MAX_GROUPS)
    end

    def label(type, pages) = type == "description" ? pages.first.meta_description : pages.first.title
  end
end
