require "rails_helper"

RSpec.describe "Crawls" do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:project) { create(:project, user:) }
  let(:domain) { create(:domain, project:, host_input: "example.com", verified_at: Time.current) }

  before do
    sign_in(user)
    SafeHttp.config.resolver = StubResolver.new("example.com" => [ "93.184.215.14" ], "rival.com" => [ "93.184.215.15" ])
  end

  def create_crawl(domain_id: domain.id, **attrs)
    post project_crawls_path(project), params: { crawl: { domain_id: }.merge(attrs) }
  end

  it "shows the form with defaults that depend on the domain" do
    rival = create(:domain, project:, host_input: "rival.com")

    get new_project_crawl_path(project, domain_id: domain.id)
    expect(response.body).to include('placeholder="500"', 'placeholder="2.0"')
    expect(response.body).not_to include("He revisado que los términos")

    get new_project_crawl_path(project, domain_id: rival.id)
    expect(response.body).to include('placeholder="200"', 'placeholder="0.5"', "He revisado que los términos de rival.com")
  end

  it "queues a crawl with the given settings, using defaults for empty fields" do
    expect { create_crawl(max_pages: "100", requests_per_second: "", exclude_patterns: "^/tag/\n\n^/wp-admin") }
      .to have_enqueued_job(Crawling::StartCrawlJob)

    crawl = Crawl.last
    expect(response).to redirect_to(crawl_path(crawl))
    expect(crawl.config).to include("start_url" => "https://example.com/", "max_pages" => 100, "requests_per_second" => 2.0,
                                    "exclude_patterns" => [ "^/tag/", "^/wp-admin" ])
  end

  it "re-renders the form with field errors for out-of-range settings" do
    create_crawl(max_pages: "0", requests_per_second: "50", exclude_patterns: "(")

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Máximo de páginas debe estar entre 1 y 50000", "Peticiones por segundo debe estar entre",
                                     "expresión regular inválida")
  end

  it "requires accepting the site's terms for unverified domains and applies their defaults" do
    rival = create(:domain, project:, host_input: "rival.com")

    create_crawl(domain_id: rival.id)
    expect(response.body).to include("debes confirmar que los términos del sitio permiten este rastreo")

    create_crawl(domain_id: rival.id, terms_accepted: "1")
    crawl = Crawl.last
    expect(crawl.config).to include("max_pages" => 200, "requests_per_second" => 0.5)
    expect(crawl.terms_accepted_at).to be_present
  end

  it "rejects a start URL whose host resolves to a private address" do
    SafeHttp.config.resolver = StubResolver.new("example.com" => [ "10.0.0.8" ])

    create_crawl

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("resuelve a una dirección bloqueada")
  end

  it "allows only one active crawl per host" do
    create_crawl
    create_crawl

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Ya hay un crawl activo para example.com")
  end

  it "pauses, resumes and cancels, rejecting invalid transitions" do
    create_crawl
    crawl = Crawl.last
    crawl.update!(status: "running")

    post pause_crawl_path(crawl)
    expect(crawl.reload.status).to eq("paused")

    expect { post resume_crawl_path(crawl) }.to have_enqueued_job(Crawling::FetchLaneJob).at_least(:once)
    expect(crawl.reload.status).to eq("running")

    post cancel_crawl_path(crawl)
    expect(crawl.reload.status).to eq("cancelled")

    post resume_crawl_path(crawl)
    expect(flash[:alert]).to include("No se puede hacer eso")
  end

  it "re-runs the audit only for completed crawls" do
    crawl = Crawl.create!(project:, domain:, config: { "start_url" => "https://example.com/" }, current_rps: 1, status: "completed")

    expect { post audit_crawl_path(crawl) }.to have_enqueued_job(Audit::RunAuditJob).with(crawl.id)
    crawl.update!(status: "running")
    expect { post audit_crawl_path(crawl) }.not_to have_enqueued_job(Audit::RunAuditJob)
  end

  it "hides other users' crawls" do
    other = create(:project)
    other_domain = create(:domain, project: other)
    crawl = Crawl.create!(project: other, domain: other_domain, config: { "start_url" => "https://x.com/" }, current_rps: 1)

    get crawl_path(crawl)
    expect(response).to have_http_status(:not_found)
    post cancel_crawl_path(crawl)
    expect(response).to have_http_status(:not_found)
    get crawl_pages_path(crawl)
    expect(response).to have_http_status(:not_found)
    post project_crawls_path(other), params: { crawl: { domain_id: other_domain.id } }
    expect(response).to have_http_status(:not_found)
  end
end
