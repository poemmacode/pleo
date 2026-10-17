module Audit
  # schema.org types and properties (config/schema_org/vocabulary.json) plus our rich-result rules.
  module SchemaVocabulary
    module_function

    def data
      @data ||= JSON.parse(Rails.root.join("config/schema_org/vocabulary.json").read)
    end

    def rules
      @rules ||= YAML.safe_load_file(Rails.root.join("config/schema_org/required_properties.yml"))
    end

    def type?(name) = data["types"].key?(name)

    def property?(name) = data["properties"].key?(name)

    def enumeration_member?(name) = data["enumeration_members"].include?(name)

    # The type and all its ancestors, e.g. Restaurant → [Restaurant, FoodEstablishment, LocalBusiness, Organization, Place, Thing].
    def ancestors(type)
      @ancestors ||= {}
      @ancestors[type] ||= begin
        seen = []
        queue = [ type ]
        while (current = queue.shift)
          next if seen.include?(current) || !type?(current)

          seen << current
          queue.concat(data["types"][current]["parents"])
        end
        seen
      end
    end

    def rules_for(type)
      ancestors(type).filter_map { rules[_1] }
    end
  end
end
