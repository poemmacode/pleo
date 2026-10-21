require "rails_helper"

RSpec.describe "Projects and domains", type: :system do
  let(:user) { create(:user, email: "ana@example.com") }

  it "rejects a wrong password, then logs in" do
    user
    visit projects_path
    fill_in "Email", with: "ana@example.com"
    fill_in "Password", with: "wrong password"
    click_button "Sign in"
    expect(page).to have_css("[role=alert]", text: "Wrong email or password")

    fill_in "Password", with: RequestHelpers::PASSWORD
    click_button "Sign in"
    expect(page).to have_css("h1", text: "Projects")
    expect(page).to have_text("You have no projects yet.")
  end

  it "creates a project, adds a domain and switches verification instructions" do
    log_in_as(user)
    fill_in "New project", with: "Blog"
    click_on "Create"
    expect(page).to have_css("h1", text: "Blog")

    fill_in "Add domain", with: "127.0.0.1"
    click_on "Add"
    expect(page).to have_css(".error", text: "Host can't be an IP address")

    fill_in "Add domain", with: "https://Example.org/"
    click_on "Add"
    domain = Domain.last
    expect(page).to have_text(domain.txt_record_value)
    expect(page).to have_no_text(Domain::Verifier.meta_tag(domain))

    choose "Meta tag"
    expect(page).to have_text(Domain::Verifier.meta_tag(domain))
    expect(page).to have_no_text("Create this DNS record")

    failure = Domain::Verifier::Result.new(false, "verification_failed", "Meta tag not found")
    expect_any_instance_of(Domain::Verifier).to receive(:call).with("meta").and_return(failure)
    click_on "Verify"
    expect(page).to have_css(".flash-alert", text: "example.org: Meta tag not found")
  end

  it "switches the interface to Spanish from the top bar and keeps it" do
    log_in_as(user)
    click_on "ES"

    expect(page).to have_css("h1", text: "Proyectos")
    expect(page).to have_css("html[lang=es]", visible: :all)
    visit projects_path
    expect(page).to have_button("Salir")
  end
end
