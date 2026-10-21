require "rails_helper"

RSpec.describe "Roles" do
  let(:member) { create(:user) }
  let(:admin) { create(:user, :admin) }

  describe "a member" do
    before { sign_in(member) }

    it "can remove a domain added by mistake, but not a verified or crawled one" do
      project = create(:project, user: member)
      typo = create(:domain, project:, host_input: "exmple.com")
      verified = create(:domain, project:, host_input: "example.com", verified_at: Time.current)
      crawled = create(:domain, project:, host_input: "example.org")
      Crawl.create!(project:, domain: crawled, config: { "start_url" => "https://example.org/" }, current_rps: 1)

      get project_path(project)
      expect(response.body.scan("Remove domain").size).to eq(1)

      delete domain_path(typo)
      expect(Domain.exists?(typo.id)).to be(false)

      [ verified, crawled ].each do |domain|
        delete domain_path(domain)
        expect(response).to redirect_to(projects_path)
        expect(Domain.exists?(domain.id)).to be(true)
      end
    end

    it "cannot see other users' projects or the admin pages" do
      foreign = create(:project, name: "Not yours")

      get projects_path
      expect(response.body).not_to include("Not yours")
      get project_path(foreign)
      expect(response).to have_http_status(:not_found)
      patch project_path(foreign), params: { project: { name: "Mine now" } }
      expect(response).to have_http_status(:not_found)

      get admin_users_path
      expect(response).to redirect_to(projects_path)
      delete admin_user_path(create(:user))
      expect(User.count).to eq(3)
    end
  end

  describe "the admin" do
    before { sign_in(admin) }

    it "sees and manages every project, including deleting them" do
      foreign = create(:project, name: "Client site")
      domain = create(:domain, project: foreign, host_input: "client.com", verified_at: Time.current)

      get projects_path
      expect(response.body).to include("Client site", "owner: #{foreign.user.email}")

      delete domain_path(domain)
      expect(Domain.exists?(domain.id)).to be(false)
      delete project_path(foreign)
      expect(response).to redirect_to(projects_path)
      expect(Project.exists?(foreign.id)).to be(false)
    end

    it "lists users and deletes members, but not the admin account" do
      other = create(:user, email: "bob@example.com")
      create(:project, user: other)

      get admin_users_path
      expect(response.body).to include("bob@example.com", admin.email)

      delete admin_user_path(other)
      expect(User.exists?(other.id)).to be(false)
      expect(Project.where(user_id: other.id)).to be_empty

      delete admin_user_path(admin)
      expect(flash[:alert]).to eq("The admin account cannot be deleted.")
      expect(User.exists?(admin.id)).to be(true)
    end
  end
end
