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
end
