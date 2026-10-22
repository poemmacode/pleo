source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.5", ">= 8.0.5.1"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Hotwire front end without Node: Propshaft assets, importmap JS, Turbo and Stimulus
gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"

# Action Cable adapter (Turbo Stream broadcasts of crawl progress)
gem "redis", "~> 5.4"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Background jobs (crawling, audits, exports)
gem "sidekiq", "~> 8.0"
# connection_pool 3.x triggers a parser bug in Ruby 3.3.0 (fixed in 3.3.1); drop this pin after upgrading Ruby
gem "connection_pool", "~> 2.5"
# json 3.x removed options ActiveSupport 8.0.5 still passes (quirks_mode); revisit when upgrading Rails
gem "json", "~> 2.10"

# Registrable-domain parsing and IDN → punycode for host normalization
gem "public_suffix", "~> 6.0"
gem "simpleidn", "~> 0.2"

# HTML parsing (verification meta tag now, page extraction in the crawler)
gem "nokogiri", "~> 1.18"

# Exportable reports (Épica F): Excel workbooks and PDF summaries, pure Ruby
gem "caxlsx", "~> 4.1"
gem "prawn", "~> 2.5"
gem "prawn-table", "~> 0.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
# gem "rack-cors"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails", "~> 6.5"

  # Audits Gemfile.lock against known advisories
  gem "bundler-audit", require: false
end

group :test do
  # System specs in headless Chrome, driven over CDP (no chromedriver binary needed)
  gem "capybara"
  gem "cuprite"
end
