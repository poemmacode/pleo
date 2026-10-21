require "rails_helper"

RSpec.describe "Interface language" do
  let(:user) { create(:user) }

  it "is English by default" do
    get new_session_path
    expect(response.body).to include('<html lang="en">', "Sign in")
  end

  it "remembers the language chosen on the login page and stores it on the user at sign-in" do
    patch locale_path, params: { locale: "es" }, headers: { "HTTP_REFERER" => new_session_url }
    expect(response).to redirect_to(new_session_url)
    follow_redirect!
    expect(response.body).to include('<html lang="es">', "Entrar")

    post session_path, params: { email: user.email, password: RequestHelpers::PASSWORD }
    expect(user.reload.locale).to eq("es")
  end

  it "switches a signed-in user's language and keeps it across sessions" do
    sign_in(user)
    patch locale_path, params: { locale: "es" }
    expect(user.reload.locale).to eq("es")

    get projects_path
    expect(response.body).to include("Proyectos", "Aún no tienes proyectos.")

    delete session_path
    sign_in(user)
    get projects_path
    expect(response.body).to include("Proyectos")
  end

  it "rejects unknown languages" do
    patch locale_path, params: { locale: "fr" }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "generates reports in the language of the user who requested them" do
    crawl = audit_crawl.tap { _1.update!(audit_status: "done") }
    crawl.project.user.update!(locale: "es")
    sign_in(crawl.project.user)
    Audit::Catalog.sync_definitions!

    post crawl_reports_path(crawl), params: { kind: "issues_csv" }

    expect(crawl.reports.sole.locale).to eq("es")
  end
end
