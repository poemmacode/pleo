require "rails_helper"

RSpec.describe "Sessions" do
  let!(:user) { create(:user, email: "ana@example.com") }

  it "logs in with an HttpOnly, SameSite=Lax session cookie and returns to the requested page" do
    project = create(:project, user:)
    get project_path(project)
    expect(response).to redirect_to(new_session_path)

    post session_path, params: { email: "ANA@example.com", password: RequestHelpers::PASSWORD }

    expect(response).to redirect_to(project_url(project))
    cookie = Array(response.headers["Set-Cookie"]).join("\n").lines.find { _1.start_with?("session_id=") }
    expect(cookie).to match(/httponly/i).and match(/samesite=lax/i)
  end

  it "re-renders the form with a generic error on bad credentials" do
    post session_path, params: { email: "ana@example.com", password: "wrong password!" }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Correo o contraseña incorrectos")
  end

  it "redirects anonymous visitors to the login page" do
    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "logs out and revokes the server-side session" do
    sign_in(user)
    expect { delete session_path }.to change(Session, :count).by(-1)
    expect(response).to redirect_to(new_session_path)

    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "rate limits login attempts" do
    10.times { post session_path, params: { email: "ana@example.com", password: "nope nope nope" } }
    post session_path, params: { email: "ana@example.com", password: RequestHelpers::PASSWORD }

    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to include("Demasiados intentos")
  end
end
