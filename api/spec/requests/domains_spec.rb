require "rails_helper"

RSpec.describe "Domains API" do
  let(:user) { create(:user) }
  let(:project) { create(:project, user:) }

  before { sign_in(user) }

  it "adds a normalized domain with DNS TXT instructions" do
    post "/api/v1/projects/#{project.id}/domains", params: { domain: { host: "https://Ejemplo.com/inicio" } }, as: :json

    expect(response).to have_http_status(:created)
    data = json["data"]
    expect(data).to include("host" => "ejemplo.com", "verified" => false)
    expect(data.dig("verification", "dns_txt")).to include("name" => "ejemplo.com", "type" => "TXT")
    expect(data.dig("verification", "dns_txt", "value")).to start_with("seo-platform-verify=")
    expect(data.dig("verification", "html_file", "url")).to match(%r{\Ahttps://ejemplo\.com/\.well-known/seo-platform-\w+\.txt\z})
    expect(data.dig("verification", "meta", "tag")).to start_with('<meta name="seo-platform-verify"')
  end

  it "rejects IPs and internal hosts with the reason" do
    post "/api/v1/projects/#{project.id}/domains", params: { domain: { host: "169.254.169.254" } }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json["errors"].first).to include("field" => "host")
    expect(json["errors"].first["detail"]).to include("dirección IP")
  end

  it "verifies a domain via DNS TXT" do
    domain = create(:domain, project:, host_input: "example.com")
    resolver = instance_double(Resolv::DNS, getresources: [ Resolv::DNS::Resource::IN::TXT.new(domain.txt_record_value) ])
    allow(Resolv::DNS).to receive(:new).and_return(resolver)
    allow(resolver).to receive(:timeouts=)

    post "/api/v1/domains/#{domain.id}/verify", params: { method: "dns_txt" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "verified")).to be(true)
  end

  it "returns 422 with the failure code when verification fails" do
    domain = create(:domain, project:, host_input: "example.com")
    resolver = instance_double(Resolv::DNS, getresources: [])
    allow(Resolv::DNS).to receive(:new).and_return(resolver)
    allow(resolver).to receive(:timeouts=)

    post "/api/v1/domains/#{domain.id}/verify", params: { method: "dns_txt" }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json["errors"].first["code"]).to eq("verification_failed")
  end

  it "does not expose or verify another user's domains" do
    foreign = create(:domain)

    get "/api/v1/domains/#{foreign.id}"
    expect(response).to have_http_status(:not_found)

    post "/api/v1/domains/#{foreign.id}/verify", params: { method: "dns_txt" }, as: :json
    expect(response).to have_http_status(:not_found)

    post "/api/v1/projects/#{foreign.project_id}/domains", params: { domain: { host: "x.com" } }, as: :json
    expect(response).to have_http_status(:not_found)
  end
end
