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
        define key: "title.missing", category: "metadata", severity: "error", weight: 8,
          title: "Falta el título",
          description: "La página no tiene <title> o está vacío. El título es una de las principales señales de relevancia y el texto del resultado.",
          fix: "Escribe un título único y descriptivo (unos 30–60 caracteres) con el tema principal de la página."

        def evaluate(page) = page.title.nil?
      end

      class TitleDuplicate < PageCheck
        include Duplicates
        define key: "title.duplicate", category: "metadata", severity: "error", weight: 6,
          title: "Títulos duplicados",
          description: "Varias páginas indexables comparten título; compiten entre sí y no se distinguen en los resultados.",
          fix: "Haz cada título único, o consolida las páginas si realmente tratan lo mismo (canonical o 301)."

        def findings
          @duplicates = duplicates_by(:title_hash)
          super
        end

        def evaluate(page) = @duplicates[page.id]&.then { duplicate_details(_1) }
      end

      class TitleTooLong < PageCheck
        define key: "title.too_long", category: "metadata", severity: "warning", weight: 2,
          title: "Título demasiado largo",
          description: "Por encima de unos 60 caracteres (≈580 px) el buscador suele cortar el título.",
          fix: "Acorta el título y pon primero lo más importante."

        def evaluate(page) = page.title && page.title.length > 60 && { length: page.title.length }
      end

      class TitleTooShort < PageCheck
        define key: "title.too_short", category: "metadata", severity: "notice", weight: 1,
          title: "Título demasiado corto",
          description: "Un título de menos de 15 caracteres rara vez describe bien la página.",
          fix: "Amplía el título con el tema concreto de la página."

        def evaluate(page) = page.title && page.title.length < 15 && { length: page.title.length }
      end

      class TitleMultiple < PageCheck
        define key: "title.multiple", category: "metadata", severity: "warning", weight: 3,
          title: "Varias etiquetas title",
          description: "Solo se usa una; las demás suelen venir de plantillas o plugins duplicados.",
          fix: "Deja un único <title> en el <head>."

        def evaluate(page) = page.title_count.to_i > 1 && { count: page.title_count }
      end

      class DescriptionMissing < PageCheck
        define key: "meta_description.missing", category: "metadata", severity: "warning", weight: 3,
          title: "Falta la meta description",
          description: "No hay meta description o está vacía; el buscador improvisa el fragmento del resultado con texto de la página.",
          fix: "Escribe una descripción única de 70–160 caracteres que invite a hacer clic."

        def applies?(page) = super && page.indexable
        def evaluate(page) = page.meta_description.nil?
      end

      class DescriptionDuplicate < PageCheck
        include Duplicates
        define key: "meta_description.duplicate", category: "metadata", severity: "warning", weight: 4,
          title: "Meta descriptions duplicadas",
          description: "Varias páginas indexables comparten descripción.",
          fix: "Redacta una descripción específica para cada página."

        def findings
          @duplicates = duplicates_by(:description_hash)
          super
        end

        def evaluate(page) = @duplicates[page.id]&.then { duplicate_details(_1) }
      end

      class DescriptionLength < PageCheck
        define key: "meta_description.length", category: "metadata", severity: "notice", weight: 1,
          title: "Meta description demasiado corta o larga",
          description: "Fuera de unos 70–160 caracteres la descripción se queda corta o se trunca.",
          fix: "Ajusta la longitud de la descripción."

        def evaluate(page)
          length = page.meta_description&.length
          length && !(70..160).cover?(length) && { length: }
        end
      end
    end
  end
end
