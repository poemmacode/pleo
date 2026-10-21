redis = { url: ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/1") }

Sidekiq.configure_server { |config| config.redis = redis }
Sidekiq.configure_client { |config| config.redis = redis }

# Start the self-scheduling health checks behind /status once job processing is up (also embedded in Puma).
Sidekiq.configure_server do |config|
  config.on(:startup) { Monitoring::HealthCheckJob.ensure_scheduled(wait: 30.seconds) }
end
