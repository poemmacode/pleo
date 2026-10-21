require "rails_helper"

RSpec.describe "Projects" do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "creates, lists and renames the user's projects" do
    post projects_path, params: { project: { name: "  Blog personal " } }
    project = Project.last
    expect(response).to redirect_to(project_path(project))
    expect(project.name).to eq("Blog personal")

    get projects_path
    expect(response.body).to include("Blog personal")

    patch project_path(project), params: { project: { name: "Company blog" } }
    expect(response).to redirect_to(project_path(project))
    expect(project.reload.name).to eq("Company blog")

    patch project_path(project), params: { project: { name: "" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(project.reload.name).to eq("Company blog")
  end

  it "does not let a member delete a project" do
    project = create(:project, user:)

    get project_path(project)
    expect(response.body).not_to include("Delete project")

    delete project_path(project)
    expect(response).to redirect_to(projects_path)
    expect(flash[:alert]).to include("Your role cannot do that")
    expect(Project.exists?(project.id)).to be(true)
  end

  it "shows a project with its crawls" do
    project = create(:project, user:)
    domain = create(:domain, project:, host_input: "example.com")
    Crawl.create!(project:, domain:, config: { "start_url" => "https://example.com/" }, current_rps: 1,
                  status: "completed", pages_crawled: 12, created_at: Time.utc(2026, 10, 20, 9, 5))

    get project_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("example.com · 20 Oct 09:05", "Completed · 12 pages")
  end

  it "re-renders the list with the validation error" do
    post projects_path, params: { project: { name: "" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Name can&#39;t be blank")
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
