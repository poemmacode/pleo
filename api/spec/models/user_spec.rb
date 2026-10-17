require "rails_helper"

RSpec.describe User do
  it "normalizes the email" do
    expect(create(:user, email: "  Ana@Example.COM ").email).to eq("ana@example.com")
  end

  it "requires a password of at least 12 characters" do
    expect(build(:user, password: "short")).not_to be_valid
  end
end
