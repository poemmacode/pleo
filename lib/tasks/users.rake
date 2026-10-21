namespace :users do
  desc "Create a member: bin/rails users:create EMAIL=you@example.com (prompts for the password, or reads PASSWORD)"
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

  # Runs on every boot (also on hosts without a shell, like Render's free plan). The ADMIN_EMAIL user is the
  # only admin: this creates it, keeps its password equal to ADMIN_PASSWORD (it cannot be changed from the
  # app) and demotes any other admin, e.g. after ADMIN_EMAIL changes. No-op when the variables are unset.
  desc "Ensure the ADMIN_EMAIL user exists as the only admin, with ADMIN_PASSWORD"
  task ensure: :environment do
    email = ENV["ADMIN_EMAIL"].presence
    password = ENV["ADMIN_PASSWORD"].presence
    next puts("users:ensure: ADMIN_EMAIL/ADMIN_PASSWORD not set, nothing to do.") unless email && password

    user = User.find_or_initialize_by(email: email.strip.downcase)
    new_password = user.new_record? || !user.authenticate(password)
    changed = new_password || !user.admin?
    User.transaction do
      User.where(role: "admin").where.not(id: user.id).update_all(role: "member", updated_at: Time.current)
      user.password = password if new_password
      user.role = "admin"
      user.save || abort(user.errors.full_messages.join("\n"))
      # A new password signs out the account everywhere (also whoever held it before, if it was a member).
      user.sessions.delete_all if new_password
    end
    puts "users:ensure: admin #{user.email} #{changed ? "ready" : "unchanged"}."
  end
end
