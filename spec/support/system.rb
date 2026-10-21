require "capybara/cuprite"

# Options go through driven_by: Rails re-registers :cuprite with its own defaults on every
# driven_by call, which would discard a separate Capybara.register_driver(:cuprite).
CUPRITE_OPTIONS = {
  headless: true, process_timeout: 30, timeout: 15, browser_path: ENV["CHROME_PATH"],
  # GitHub's Ubuntu runners restrict the user namespaces Chrome's sandbox needs.
  browser_options: ENV["CI"] ? { "no-sandbox" => nil } : {}
}

module SystemHelpers
  def log_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: RequestHelpers::PASSWORD
    click_button "Sign in"
    expect(page).to have_css("header.topbar", text: user.email)
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system

  config.before(type: :system) do
    driven_by :cuprite, screen_size: [ 1280, 1000 ], options: CUPRITE_OPTIONS
    RateLimitStore::STORE.clear
  end

  # Broadcasts must reach the browser: use the in-process async adapter for system specs only.
  config.around(type: :system) do |example|
    ActionCable.server.config.cable = { "adapter" => "async" }
    ActionCable.server.restart
    example.run
  ensure
    ActionCable.server.config.cable = { "adapter" => "test" }
    ActionCable.server.restart
  end
end
