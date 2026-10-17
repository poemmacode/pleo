require "rails_helper"

RSpec.describe "Projects and domains", type: :system do
  let(:user) { create(:user, email: "ana@example.com") }

  it "rejects a wrong password, then logs in" do
    user
    visit root_path
    fill_in "Correo", with: "ana@example.com"
    fill_in "Contraseña", with: "contraseña mala"
    click_on "Entrar"
    expect(page).to have_css("[role=alert]", text: "Correo o contraseña incorrectos")

    fill_in "Contraseña", with: RequestHelpers::PASSWORD
    click_on "Entrar"
    expect(page).to have_css("h1", text: "Proyectos")
    expect(page).to have_text("Aún no tienes proyectos.")
  end

  it "creates a project, adds a domain and switches verification instructions" do
    log_in_as(user)
    fill_in "Nuevo proyecto", with: "Blog"
    click_on "Crear"
    expect(page).to have_css("h1", text: "Blog")

    fill_in "Añadir dominio", with: "127.0.0.1"
    click_on "Añadir"
    expect(page).to have_css(".error", text: "Host no puede ser una dirección IP")

    fill_in "Añadir dominio", with: "https://Ejemplo.com/"
    click_on "Añadir"
    domain = Domain.last
    expect(page).to have_text(domain.txt_record_value)
    expect(page).to have_no_text(Domain::Verifier.meta_tag(domain))

    choose "Etiqueta meta"
    expect(page).to have_text(Domain::Verifier.meta_tag(domain))
    expect(page).to have_no_text("Crea este registro DNS")

    failure = Domain::Verifier::Result.new(false, "verification_failed", "No se encontró la etiqueta meta")
    expect_any_instance_of(Domain::Verifier).to receive(:call).with("meta").and_return(failure)
    click_on "Verificar"
    expect(page).to have_css(".flash-alert", text: "ejemplo.com: No se encontró la etiqueta meta")
  end
end
