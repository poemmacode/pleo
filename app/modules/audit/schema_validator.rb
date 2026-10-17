module Audit
  # Checks a structured data item: known types, known properties, and our rich-result rules,
  # recursing into nested items (e.g. Product → offers → Offer).
  module SchemaValidator
    MAX_DEPTH = 6

    module_function

    # Returns [errors, warnings] as arrays of { code:, type:, property:, path: }.
    def validate(data)
      errors = []
      warnings = []
      walk(data, "", errors, warnings, 0) if data.is_a?(Hash)
      [ errors.uniq, warnings.uniq ]
    end

    def walk(node, path, errors, warnings, depth)
      return if depth > MAX_DEPTH

      types = Array(node["@type"]).map { _1.to_s.sub(Crawling::StructuredDataExtractor::SCHEMA_PREFIX, "") }
      types.each do |type|
        unless SchemaVocabulary.type?(type)
          errors << finding("unknown_type", type, nil, path)
          next
        end
        check_rules(node, type, path, errors, warnings)
      end

      node.each do |key, value|
        next if key.start_with?("@")

        property = key.sub(Crawling::StructuredDataExtractor::SCHEMA_PREFIX, "")
        warnings << finding("unknown_property", types.first, property, path) if types.any? && !SchemaVocabulary.property?(property)
        (value.is_a?(Array) ? value : [ value ]).each_with_index do |child, index|
          next unless child.is_a?(Hash)

          child_path = [ path.presence, value.is_a?(Array) ? "#{property}[#{index}]" : property ].compact.join(".")
          walk(child, child_path, errors, warnings, depth + 1)
        end
      end
    end

    def check_rules(node, type, path, errors, warnings)
      SchemaVocabulary.rules_for(type).each do |rule|
        Array(rule["required"]).each do |property|
          errors << finding("missing_required", type, property, path) if blank_value?(node[property])
        end
        Array(rule["one_of"]).each do |group|
          errors << finding("missing_one_of", type, group.join(" | "), path) if group.all? { blank_value?(node[_1]) }
        end
        Array(rule["recommended"]).each do |property|
          warnings << finding("missing_recommended", type, property, path) if blank_value?(node[property])
        end
      end
    end

    def blank_value?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?) || (value.is_a?(String) && value.strip.empty?)
    end

    def finding(code, type, property, path) = { code:, type:, property:, path: path.presence }.compact
  end
end
