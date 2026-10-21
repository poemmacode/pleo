require "rails_helper"
require "rake"

RSpec.describe "users:ensure" do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.empty? }

  def run(email: "Admin@Example.com", password: "admin password 123")
    stub_const("ENV", ENV.to_h.merge("ADMIN_EMAIL" => email, "ADMIN_PASSWORD" => password))
    Rake::Task["users:ensure"].reenable
    expect { Rake::Task["users:ensure"].invoke }.to output(/users:ensure/).to_stdout
  end

  it "makes the ADMIN_EMAIL user the only admin, with the password from the environment" do
    old_admin = create(:user, :admin, email: "old@example.com")

    run
    admin = User.find_by!(email: "admin@example.com")
    expect(admin).to be_admin
    expect(admin.authenticate("admin password 123")).to be_truthy
    expect(old_admin.reload.role).to eq("member")
  end

  it "takes over an existing account with that email and resets its password and sessions" do
    squatter = create(:user, email: "admin@example.com")
    squatter.sessions.create!

    run
    expect(squatter.reload).to be_admin
    expect(squatter.authenticate(RequestHelpers::PASSWORD)).to be(false)
    expect(squatter.sessions).to be_empty
  end

  it "keeps sessions when nothing changed" do
    run
    admin = User.find_by!(email: "admin@example.com")
    admin.sessions.create!

    run
    expect(admin.sessions.count).to eq(1)
  end
end
