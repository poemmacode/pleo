module Audit
  module Checks
    module StructuredData
      # Rows from Context#structured_data: [page_id, syntax, types, valid_syntax, validation_errors]
      class InvalidJson < PageCheck
        define key: "schema.invalid_json", category: "structured_data", severity: "error", weight: 6,
          title: "JSON-LD con errores de sintaxis",
          description: "Un bloque JSON-LD no se puede leer, así que los buscadores lo ignoran entero.",
          fix: "Valida el JSON (comas finales, comillas, llaves) y corrige el bloque."

        def evaluate(page)
          broken = context.structured_data(page.id).reject { _1[3] }
          broken.any? && { blocks: broken.size, errors: broken.flat_map { _1[4] }.first(3) }
        end
      end

      class UnknownType < PageCheck
        define key: "schema.unknown_type", category: "structured_data", severity: "warning", weight: 3,
          title: "Tipos de schema.org desconocidos",
          description: "Se usa un @type que no existe en schema.org (a menudo una errata).",
          fix: "Corrige el tipo usando el nombre exacto de schema.org (respeta mayúsculas)."

        def evaluate(page)
          types = context.structured_data(page.id).flat_map { _1[4] }.select { _1["code"] == "unknown_type" }.map { _1["type"] }
          types.any? && { types: types.uniq }
        end
      end

      class MissingRequired < PageCheck
        define key: "schema.missing_required", category: "structured_data", severity: "warning", weight: 4,
          title: "Faltan propiedades necesarias para resultados enriquecidos",
          description: "El marcado no incluye propiedades que los buscadores exigen para mostrar resultados enriquecidos de ese tipo.",
          fix: "Añade las propiedades indicadas en cada tipo."

        CODES = %w[missing_required missing_one_of].freeze

        def evaluate(page)
          missing = context.structured_data(page.id).flat_map { _1[4] }.select { CODES.include?(_1["code"]) }
          missing.any? && { missing: missing.first(10).map { [ _1["type"], _1["property"], _1["path"] ].compact.join(" · ") } }
        end
      end

      class None < PageCheck
        define key: "schema.none", category: "structured_data", severity: "notice", weight: 1,
          title: "Sin datos estructurados",
          description: "La página no tiene marcado schema.org; podría optar a resultados enriquecidos o ayudar a entender la entidad.",
          fix: "Añade JSON-LD adecuado al tipo de página (Article, Product, BreadcrumbList, Organization…)."

        def applies?(page) = super && page.indexable
        def evaluate(page) = context.structured_data(page.id).empty?
      end
    end
  end
end
