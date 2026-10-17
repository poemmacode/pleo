require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app, window_size: [ 1280, 1000 ], headless: true, process_timeout: 30, timeout: 15,
    browser_path: ENV["CHROME_PATH"], browser_options: ENV["CI"] ? { "no-sandbox" => nil } : {}
  )
end

module SystemHelpers
  def log_in_as(user)
    visit new_session_path
    fill_in "Correo", with: user.email
    fill_in "Contraseña", with: RequestHelpers::PASSWORD
    click_on "Entrar"
    expect(page).to have_css("header.topbar", text: user.email)
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system

  config.before(type: :system) do
    driven_by :cuprite
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
