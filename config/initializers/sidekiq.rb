redis = { url: ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/1") }

Sidekiq.configure_server { |config| config.redis = redis }
Sidekiq.configure_client { |config| config.redis = redis }
