# One probe of the application's own health (Monitoring::HealthCheckJob), shown on /status.
class UptimeCheck < ApplicationRecord
  STATUSES = %w[ok degraded down].freeze
  RETENTION = 90.days

  validates :status, inclusion: { in: STATUSES }

  scope :since, ->(time) { where(checked_at: time..) }
end
