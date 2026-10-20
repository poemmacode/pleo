namespace :users do
  desc "Create a user: bin/rails users:create EMAIL=you@example.com (prompts for the password, or reads PASSWORD)"
  task create: :environment do
    require "io/console"

    email = ENV.fetch("EMAIL") { abort "Falta EMAIL=..." }
    password = ENV["PASSWORD"].presence || begin
      print "Contraseña (mínimo #{User::MIN_PASSWORD_LENGTH} caracteres): "
      STDIN.noecho(&:gets).to_s.chomp.tap { puts }
    end

    user = User.new(email:, password:)
    if user.save
      puts "Usuario #{user.email} creado (id #{user.id})."
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
    next puts("users:ensure: ADMIN_EMAIL/ADMIN_PASSWORD no definidos, nada que hacer.") unless email && password

    user = User.find_or_initialize_by(email: email.strip.downcase)
    if user.new_record? || !user.authenticate(password)
      user.password = password
      user.save ? puts("users:ensure: usuario #{user.email} listo.") : abort(user.errors.full_messages.join("\n"))
    else
      puts "users:ensure: usuario #{user.email} sin cambios."
    end
  end
end
