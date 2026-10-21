module Monitoring
  # Records a HealthProbe every INTERVAL and schedules the next run. A Redis key with NX makes sure only
  # one chain runs however many times it is kicked off (Sidekiq startup, the /status page).
  class HealthCheckJob < ApplicationJob
    INTERVAL = 5.minutes
    LOCK_KEY = "monitoring:health_check:next".freeze

    queue_as :default

    # Enqueues the next check unless one is already scheduled.
    def self.ensure_scheduled(wait: INTERVAL)
      return false unless SafeHttp.redis.call("SET", LOCK_KEY, Time.current.to_i, "NX", "EX", (wait + 1.minute).to_i)

      set(wait:).perform_later
      true
    rescue RedisClient::Error
      false
    end

    def perform
      result = HealthProbe.call
      UptimeCheck.create!(checked_at: Time.current, status: result.status, components: result.components,
                          duration_ms: result.duration_ms)
      UptimeCheck.where(checked_at: ...UptimeCheck::RETENTION.ago).delete_all
    ensure
      SafeHttp.redis.call("DEL", LOCK_KEY) rescue nil
      self.class.ensure_scheduled
    end
  end
end
