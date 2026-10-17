require "rails_helper"

RSpec.describe "Domains" do
  let(:user) { create(:user) }
  let(:project) { create(:project, user:) }

  before { sign_in(user) }

  it "adds a normalized domain and shows the three verification methods" do
    post project_domains_path(project), params: { domain: { host: "https://Ejemplo.com/inicio" } }
    expect(response).to redirect_to(project_path(project))

    domain = project.domains.last
    follow_redirect!
    expect(response.body).to include("ejemplo.com", domain.txt_record_value, "/.well-known/seo-platform-#{domain.verification_token}.txt",
                                     "seo-platform-verify")
  end

  it "rejects IPs and internal hosts with the reason" do
    post project_domains_path(project), params: { domain: { host: "169.254.169.254" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Host no puede ser una dirección IP")
  end

  it "verifies a domain via DNS TXT" do
    domain = create(:domain, project:, host_input: "example.com")
    resolver = instance_double(Resolv::DNS, getresources: [ Resolv::DNS::Resource::IN::TXT.new(domain.txt_record_value) ])
    allow(Resolv::DNS).to receive(:new).and_return(resolver)
    allow(resolver).to receive(:timeouts=)

    post verify_domain_path(domain), params: { method: "dns_txt" }

    expect(response).to redirect_to(project_path(project))
    expect(flash[:notice]).to eq("example.com verificado.")
    expect(domain.reload).to be_verified
  end

  it "shows why verification failed" do
    domain = create(:domain, project:, host_input: "example.com")
    resolver = instance_double(Resolv::DNS, getresources: [])
    allow(Resolv::DNS).to receive(:new).and_return(resolver)
    allow(resolver).to receive(:timeouts=)

    post verify_domain_path(domain), params: { method: "dns_txt" }

    expect(flash[:alert]).to include("No se encontró el registro TXT")
  end

  it "does not expose or change another user's domains" do
    foreign = create(:domain)

    post verify_domain_path(foreign), params: { method: "dns_txt" }
    expect(response).to have_http_status(:not_found)
    delete domain_path(foreign)
    expect(response).to have_http_status(:not_found)
    post project_domains_path(foreign.project), params: { domain: { host: "x.com" } }
    expect(response).to have_http_status(:not_found)
  end
end
