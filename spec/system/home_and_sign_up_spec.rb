require "rails_helper"

RSpec.describe "Home and sign-up", type: :system do
  it "goes from the home page to a new member account" do
    visit root_path
    expect(page).to have_css("h1", text: "Find and fix the issues")

    within(".hero") { click_on "Create a free account" }
    fill_in "Work email", with: "new@example.com"
    fill_in "Password (at least 12 characters)", with: RequestHelpers::PASSWORD
    fill_in "Confirm password", with: RequestHelpers::PASSWORD
    click_button "Create account"

    expect(page).to have_css(".flash-notice", text: "Welcome!")
    expect(page).to have_css("header.topbar", text: "new@example.com")
    expect(page).to have_no_link("Users")
    expect(User.find_by!(email: "new@example.com").role).to eq("member")
  end
end
