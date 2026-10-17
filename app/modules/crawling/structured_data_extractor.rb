module Crawling
  # Collects schema.org items from JSON-LD, Microdata and RDFa (Lite). Each item becomes one row in
  # page_structured_data; validation against the vocabulary happens in Audit::SchemaValidator.
  module StructuredDataExtractor
    MAX_ITEMS = 50
    MAX_JSON_BYTES = 100_000
    SCHEMA_PREFIX = %r{\A(?:https?://schema\.org/|schema:)}i

    module_function

    def extract(doc, url)
      (json_ld(doc) + microdata(doc) + rdfa(doc)).first(MAX_ITEMS)
    end

    def item(syntax, data, valid: true, error: nil)
      { syntax:, types: types_of(data), data:, valid_syntax: valid, validation_errors: error ? [ error ] : [], validation_warnings: [] }
    end

    def types_of(data)
      return [] unless data.is_a?(Hash)

      Array(data["@type"]).map { _1.to_s.sub(SCHEMA_PREFIX, "") }.reject(&:empty?)
    end

    # --- JSON-LD ---------------------------------------------------------------------------------
    def json_ld(doc)
      doc.css("script[type]").select { _1["type"].strip.casecmp?("application/ld+json") }.flat_map do |script|
        source = script.text.strip.sub(/\A<!--/, "").sub(/-->\z/, "").sub(/\A<!\[CDATA\[/, "").sub(/\]\]>\z/, "")
        if source.bytesize > MAX_JSON_BYTES
          next [ item("json-ld", nil, valid: false, error: "bloque JSON-LD de más de #{MAX_JSON_BYTES} bytes") ]
        end

        parsed = JSON.parse(source)
        nodes = (parsed.is_a?(Array) ? parsed : [ parsed ]).flat_map { _1.is_a?(Hash) && _1["@graph"].is_a?(Array) ? _1["@graph"] : [ _1 ] }
        nodes.select { _1.is_a?(Hash) }.map { item("json-ld", _1) }
      rescue JSON::ParserError => e
        [ item("json-ld", nil, valid: false, error: "JSON inválido: #{e.message.first(200)}") ]
      end
    end

    # --- Microdata -------------------------------------------------------------------------------
    def microdata(doc)
      doc.css("[itemscope]").reject { _1.has_attribute?("itemprop") }.map { item("microdata", microdata_item(_1)) }
    end

    def microdata_item(node, depth = 0)
      data = { "@type" => node["itemtype"].to_s.split.map { _1.sub(SCHEMA_PREFIX, "") }.then { _1.size == 1 ? _1.first : _1 } }
      collect_properties(node, "itemprop", "itemscope", data, depth) { |child| microdata_item(child, depth + 1) }
      data
    end

    # --- RDFa Lite -------------------------------------------------------------------------------
    def rdfa(doc)
      doc.css("[typeof]").reject { _1.has_attribute?("property") }.map { item("rdfa", rdfa_item(_1)) }
    end

    def rdfa_item(node, depth = 0)
      data = { "@type" => node["typeof"].to_s.split.map { _1.sub(SCHEMA_PREFIX, "") }.then { _1.size == 1 ? _1.first : _1 } }
      collect_properties(node, "property", "typeof", data, depth) { |child| rdfa_item(child, depth + 1) }
      data
    end

    # Walks descendants until the next nested item, so each property belongs to its nearest item.
    def collect_properties(node, prop_attr, scope_attr, data, depth, &nested)
      return if depth > 10

      node.element_children.each do |child|
        names = child[prop_attr].to_s.split.map { _1.sub(SCHEMA_PREFIX, "") }
        if names.any?
          value = child.has_attribute?(scope_attr) ? nested.call(child) : property_value(child)
          names.each { |name| data[name] = data.key?(name) ? Array.wrap(data[name]) + [ value ] : value }
        end
        collect_properties(child, prop_attr, scope_attr, data, depth, &nested) unless child.has_attribute?(scope_attr)
      end
    end

    def property_value(node)
      return node["content"] if node.has_attribute?("content")

      case node.name
      when "meta" then node["content"].to_s
      when "img", "audio", "video", "source", "embed", "iframe", "track" then node["src"].to_s
      when "a", "area", "link" then node["href"].to_s
      when "object" then node["data"].to_s
      when "time" then node["datetime"] || node.text.squish
      when "data", "meter" then node["value"].to_s
      else node["resource"] || node.text.squish.first(1000)
      end
    end
  end
end
