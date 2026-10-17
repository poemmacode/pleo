module Audit
  module Checks
    module Content
      class H1Missing < PageCheck
        define key: "h1.missing", category: "content", severity: "warning", weight: 4,
          title: "Falta el H1",
          description: "El encabezado principal ayuda a usuarios y buscadores a entender de qué trata la página.",
          fix: "Añade un único <h1> visible con el tema de la página."

        def evaluate(page) = page.h1.empty?
      end

      class H1Multiple < PageCheck
        define key: "h1.multiple", category: "content", severity: "notice", weight: 1,
          title: "Varios H1",
          description: "Varios H1 no son un error en HTML5, pero suelen indicar una jerarquía poco clara.",
          fix: "Usa un H1 para el tema principal y H2/H3 para las secciones."

        def evaluate(page) = page.h1.size > 1 && { count: page.h1.size }
      end

      class HeadingsSkipped < PageCheck
        define key: "headings.skipped_level", category: "content", severity: "notice", weight: 1,
          title: "Saltos en la jerarquía de encabezados",
          description: "Se salta un nivel (por ejemplo de H2 a H4), lo que dificulta la lectura con lectores de pantalla.",
          fix: "Encadena los niveles sin saltos (H1 → H2 → H3)."

        def evaluate(page)
          levels = page.headings.map { _1["level"] }
          skips = levels.each_cons(2).select { |a, b| b > a + 1 }
          skips.any? && { skips: skips.first(5).map { |a, b| "H#{a} → H#{b}" } }
        end
      end

      class H1EqualsTitle < PageCheck
        define key: "h1.equals_title", category: "content", severity: "notice", weight: 1,
          title: "H1 idéntico al título",
          description: "No es un error, pero es una oportunidad perdida de cubrir variantes del tema.",
          fix: "Opcional: usa el H1 para una formulación complementaria del título."

        def evaluate(page) = page.title && page.h1.first&.casecmp?(page.title)
      end

      class Thin < PageCheck
        MIN_WORDS = 200
        define key: "content.thin", category: "content", severity: "warning", weight: 3,
          title: "Poco contenido",
          description: "Menos de 200 palabras de texto visible en una página indexable; puede considerarse de poco valor.",
          fix: "Amplía el contenido con información útil o, si la página no aporta, desindéxala o consolídala."

        def applies?(page) = super && page.indexable
        def evaluate(page) = page.word_count.to_i < MIN_WORDS && { words: page.word_count }
      end

      class NearDuplicate < PageCheck
        MIN_WORDS = 50
        define key: "content.duplicate", category: "content", severity: "warning", weight: 5,
          title: "Contenido casi duplicado",
          description: "El texto es prácticamente igual al de otras páginas indexables.",
          fix: "Diferencia el contenido o consolida las páginas con canonical o redirección 301."

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
        define key: "images.missing_alt", category: "content", severity: "warning", weight: 2,
          title: "Imágenes sin atributo alt",
          description: "Sin alt, las imágenes no son accesibles y los buscadores no saben qué muestran.",
          fix: "Añade un alt descriptivo; usa alt=\"\" solo en imágenes decorativas."

        def evaluate(page) = page.images_missing_alt.to_i.positive? && { images: page.images_missing_alt, total: page.images_count }
      end
    end
  end
end
