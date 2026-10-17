require "rails_helper"

RSpec.describe "Crawls", type: :system do
  let(:user) { create(:user) }
  let(:project) { create(:project, user:, name: "Blog") }
  let!(:domain) { create(:domain, project:, host_input: "example.com", verified_at: Time.current) }

  before { SafeHttp.config.resolver = StubResolver.new("example.com" => [ "93.184.215.14" ], "rival.com" => [ "93.184.215.15" ]) }

  it "adapts the new-crawl form to the chosen domain and shows field errors" do
    create(:domain, project:, host_input: "rival.com")
    log_in_as(user)
    visit new_project_crawl_path(project, domain_id: domain.id)
    expect(page).to have_field("Máximo de páginas", placeholder: "500")
    expect(page).to have_no_text("He revisado que los términos")

    select "rival.com (sin verificar)", from: "crawl_domain_id"
    expect(page).to have_field("Máximo de páginas", placeholder: "200")
    expect(page).to have_field("Peticiones por segundo", placeholder: "0.5")
    click_on "Iniciar crawl"

    expect(page).to have_css(".error", text: "debes confirmar que los términos del sitio permiten este rastreo")
    check "He revisado que los términos de rival.com permiten este rastreo"
    click_on "Iniciar crawl"
    expect(page).to have_css("h1", text: "Crawl de rival.com")
  end

  it "updates progress live and lets the user pause" do
    crawl = Crawl.create!(project:, domain:, status: "running", current_rps: 2, sitemap_status: "done",
                          config: { "start_url" => "https://example.com/", "max_pages" => 100 })
    log_in_as(user)
    visit crawl_path(crawl)
    expect(page).to have_text("Rastreando")
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)

    crawl.update!(pages_discovered: 40, pages_crawled: 12)
    Crawling::ProgressBroadcaster.call(crawl, force: true)
    within("#progress_crawl_#{crawl.id}") do
      expect(page).to have_css("dd", text: "12")
      expect(page).to have_css("[role=progressbar][aria-valuenow='30']")
    end

    click_on "Pausar"
    expect(page).to have_text("En pausa")
    expect(page).to have_button("Reanudar")
    expect(crawl.reload.status).to eq("paused")
  end

  it "expands an issue, loads its findings lazily and opens the page detail" do
    Audit::Catalog.sync_definitions!
    crawl = Crawl.create!(project:, domain:, status: "completed", audit_status: "done", current_rps: 1,
                          config: { "start_url" => "https://example.com/" })
    url = "https://example.com/rota"
    crawl_url = CrawlUrl.create!(crawl:, url:, url_hash: CrawlUrl.hash_url(url), source: "link", state: "done")
    broken = Page.create!(crawl:, crawl_url:, url:, status_code: 404, fetched_at: Time.current)
    Issue.create!(crawl:, check_key: "http.4xx", page: broken, url:, details: { "status" => 404 })

    log_in_as(user)
    visit crawl_path(crawl)
    find("summary", text: "Páginas con error 4xx").click
    within("details[open]") do
      expect(page).to have_text("Restaura la página")
      click_on url
    end

    expect(page).to have_css("h1", text: url)
    expect(page).to have_text("Páginas con error 4xx")
  end
end
