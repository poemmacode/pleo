require "sidekiq/api"

module Monitoring
  # Checks the application's own dependencies: the database, Redis and the background job processes.
  # The database being unreachable means "down"; any other failure means "degraded".
  class HealthProbe
    QUEUE_LATENCY_LIMIT = 10.minutes

    Result = Data.define(:status, :components, :duration_ms)

    def self.call = new.call

    def call
      started = monotonic_ms
      components = { "database" => measure { database }, "redis" => measure { redis }, "jobs" => measure { jobs } }
      Result.new(status: overall(components), components:, duration_ms: monotonic_ms - started)
    end

    private
      def database
        ActiveRecord::Base.connection.select_value("SELECT 1")
        "ok"
      end

      def redis
        SafeHttp.redis.call("PING") == "PONG" ? "ok" : "down"
      end

      # A queue nobody drains shows up as no live process or as old jobs waiting.
      def jobs
        return "down" if Sidekiq::ProcessSet.new.size.zero?

        Sidekiq::Queue.all.map(&:latency).max.to_f > QUEUE_LATENCY_LIMIT ? "degraded" : "ok"
      end

      def measure
        started = monotonic_ms
        status = yield
        { "status" => status, "ms" => monotonic_ms - started }
      rescue StandardError => e
        Rails.logger.warn("[health] #{e.class}: #{e.message}")
        { "status" => "down", "ms" => monotonic_ms - started }
      end

      def overall(components)
        return "down" if components.dig("database", "status") == "down"

        components.values.all? { _1["status"] == "ok" } ? "ok" : "degraded"
      end

      def monotonic_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
  end
end
