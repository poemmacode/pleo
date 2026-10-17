namespace :schema_org do
  desc "Rebuild config/schema_org/vocabulary.json from schema.org (types, hierarchy, properties). SOURCE=path to use a local file."
  task refresh: :environment do
    url = "https://schema.org/version/latest/schemaorg-current-https.jsonld"
    raw = ENV["SOURCE"] ? File.read(ENV["SOURCE"]) : SafeHttp::Client.new(max_bytes: 20.megabytes, total_timeout: 60).get(url).body
    graph = JSON.parse(raw).fetch("@graph")

    ids = ->(value) { Array.wrap(value).map { _1["@id"] } }
    short = ->(id) { id.delete_prefix("schema:") }
    schema = ->(id) { id.to_s.start_with?("schema:") }

    types = {}
    properties = {}
    graph.each do |node|
      next unless schema.(node["@id"])

      kinds = Array.wrap(node["@type"])
      if kinds.intersect?(%w[rdfs:Class schema:DataType])
        types[short.(node["@id"])] = { parents: ids.(node["rdfs:subClassOf"]).select(&schema).map(&short) }
      end
      if kinds.include?("rdf:Property")
        properties[short.(node["@id"])] = { domains: ids.(node["schema:domainIncludes"]).map(&short), superseded: node.key?("schema:supersededBy") }
      end
    end
    members = graph.select { |n| schema.(n["@id"]) && n["@type"].is_a?(String) && schema.(n["@type"]) && types.key?(short.(n["@type"])) }
      .map { short.(_1["@id"]) }.sort

    out = { source: url, license: "CC BY-SA 3.0 (schema.org)", snapshot_date: Date.current.iso8601,
            types:, properties:, enumeration_members: members }
    path = Rails.root.join("config/schema_org/vocabulary.json")
    File.write(path, JSON.generate(out.deep_stringify_keys.sort.to_h))
    puts "#{types.size} tipos, #{properties.size} propiedades, #{members.size} miembros → #{path}"
  end
end
