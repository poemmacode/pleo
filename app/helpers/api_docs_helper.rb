module ApiDocsHelper
  # Resolves a local "$ref" ("#/components/...") in the OpenAPI document.
  def openapi_ref(spec, node)
    return node unless node.is_a?(Hash) && node["$ref"]

    node["$ref"].delete_prefix("#/").split("/").reduce(spec) { |doc, key| doc.fetch(key) }
  end

  def openapi_schema_name(node)
    node.is_a?(Hash) && node["$ref"] ? node["$ref"].split("/").last : nil
  end

  # Inline code spans (`x`) and bold (**x**) from the spec's descriptions; everything else is escaped.
  def openapi_text(text)
    html = ERB::Util.html_escape(text.to_s)
    html = html.gsub(/\*\*(.+?)\*\*/) { "<strong>#{$1}</strong>" }.gsub(/`([^`]+)`/) { "<code>#{$1}</code>" }
    safe_join(html.split(/\n{2,}/).map { tag.p(_1.html_safe) }) # rubocop:disable Rails/OutputSafety
  end

  def openapi_example_body(spec, operation)
    content = operation.dig("requestBody", "content", "application/json")
    content && (content["example"] || openapi_ref(spec, content["schema"])&.dig("example"))
  end

  def openapi_anchor(operation) = operation.fetch("operationId").underscore.dasherize
end
