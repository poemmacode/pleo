require "rails_helper"

# Keeps docs/api/openapi.yaml and the API routes in step, and checks the public docs page renders it.
RSpec.describe "API documentation" do
  let(:spec) { ApiDocsController.spec }

  it "documents exactly the routes under /api/v1" do
    routes = Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.delete_suffix("(.:format)")
      # Rails routes PUT and PATCH to update; the spec documents PATCH only.
      next unless path.start_with?("/api/v1/") && route.verb != "PUT"

      [ route.verb.downcase, path.delete_prefix("/api/v1").gsub(/:(\w+)/, '{\1}') ]
    end
    documented = spec.fetch("paths").flat_map { |path, item| (item.keys - [ "parameters" ]).map { [ _1, path ] } }

    expect(documented).to match_array(routes)
  end

  it "resolves every reference" do
    refs = spec.to_s.scan(%r{"\$ref"=>"#/([^"]+)"}).flatten.uniq
    refs.each { |ref| expect(ref.split("/").reduce(spec) { |doc, key| doc&.fetch(key, nil) }).to be_present, ref }
  end

  it "renders the reference page and serves the raw specification without signing in" do
    get api_docs_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("SEO Platform API", "/api/v1/projects/{project_id}/crawls", "Authorization: Bearer",
                                     "createCrawl".underscore.dasherize)

    get api_spec_path
    expect(response.media_type).to eq("application/yaml")
    expect(response.body).to start_with("openapi: 3.1.0")
  end
end
