require "rails_helper"

RSpec.describe "Home" do
  it "presents the product to visitors and asks them to sign in" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Find and fix the issues", "58-check technical audit", "Create a free account",
                                     new_session_path, api_docs_path, status_path)
  end

  it "sends signed-in users to their projects" do
    sign_in(create(:user))

    get root_path
    expect(response).to redirect_to(projects_path)
  end
end
