namespace :users do
  desc "Create a user: bin/rails users:create EMAIL=you@example.com (prompts for the password, or reads PASSWORD)"
  task create: :environment do
    require "io/console"

    email = ENV.fetch("EMAIL") { abort "Missing EMAIL=..." }
    password = ENV["PASSWORD"].presence || begin
      print "Password (at least #{User::MIN_PASSWORD_LENGTH} characters): "
      STDIN.noecho(&:gets).to_s.chomp.tap { puts }
    end

    user = User.new(email:, password:)
    if user.save
      puts "User #{user.email} created (id #{user.id})."
    else
      abort user.errors.full_messages.join("\n")
    end
  end

  # For hosts without a shell (Render free plan): runs on every boot. Creates the user from
  # ADMIN_EMAIL / ADMIN_PASSWORD, or updates the password if it changed. No-op when unset.
  desc "Ensure the ADMIN_EMAIL user exists with ADMIN_PASSWORD"
  task ensure: :environment do
    email = ENV["ADMIN_EMAIL"].presence
    password = ENV["ADMIN_PASSWORD"].presence
    next puts("users:ensure: ADMIN_EMAIL/ADMIN_PASSWORD not set, nothing to do.") unless email && password

    user = User.find_or_initialize_by(email: email.strip.downcase)
    if user.new_record? || !user.authenticate(password)
      user.password = password
      user.save ? puts("users:ensure: user #{user.email} ready.") : abort(user.errors.full_messages.join("\n"))
    else
      puts "users:ensure: user #{user.email} unchanged."
    end
  end
end
