# Public API reference, rendered from docs/api/openapi.yaml (also served raw for client generators).
class ApiDocsController < ApplicationController
  SPEC_PATH = Rails.root.join("docs/api/openapi.yaml")
  HTTP_METHODS = %w[get post patch put delete].freeze

  allow_unauthenticated_access

  def show
    @spec = self.class.spec
    @operations = @spec.fetch("paths").flat_map do |path, item|
      HTTP_METHODS.filter_map { |verb| item[verb] && { path:, verb:, operation: item[verb], shared: item["parameters"] || [] } }
    end.group_by { _1[:operation].fetch("tags").first }
  end

  def spec
    send_file SPEC_PATH, type: "application/yaml", disposition: "inline"
  end

  def self.spec
    @spec = nil if Rails.env.development?
    @spec ||= YAML.safe_load_file(SPEC_PATH, aliases: false)
  end
end
