require "rails_helper"

RSpec.describe "Projects" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "creates, lists and deletes the user's projects" do
    post projects_path, params: { project: { name: "  Blog personal " } }
    project = Project.last
    expect(response).to redirect_to(project_path(project))
    expect(project.name).to eq("Blog personal")

    get root_path
    expect(response.body).to include("Blog personal")

    delete project_path(project)
    expect(response).to redirect_to(root_path)
    expect(Project.exists?(project.id)).to be(false)
  end

  it "re-renders the list with the validation error" do
    post projects_path, params: { project: { name: "" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Nombre no puede estar vacío")
  end

  it "hides other users' projects" do
    other = create(:project)

    get project_path(other)
    expect(response).to have_http_status(:not_found)

    delete project_path(other)
    expect(response).to have_http_status(:not_found)
    expect(Project.exists?(other.id)).to be(true)
  end
end
