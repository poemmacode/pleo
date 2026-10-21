module Monitoring
  # Uptime figures for /status from the recorded UptimeChecks. Periods without checks (the app asleep on
  # a free host, or fully down) are "no data", not downtime: an app cannot record its own outage.
  class Uptime
    WINDOWS = { "24h" => 24.hours, "7d" => 7.days, "30d" => 30.days }.freeze
    DAYS = 30
    Day = Data.define(:date, :checks, :ok, :percent)
    Incident = Data.define(:started_at, :ended_at, :status, :components)

    def initialize(now: Time.current)
      @now = now
    end

    # { "24h" => { percent: 99.9, checks: 280, coverage: 97.2 }, ... }; percent is nil without data.
    def windows
      WINDOWS.to_h do |label, length|
        counts = UptimeCheck.since(@now - length).group(:status).count
        total = counts.values.sum
        expected = (length / HealthCheckJob::INTERVAL).floor
        [ label, { percent: percent(counts["ok"].to_i, total), checks: total, coverage: [ percent(total, expected) || 0, 100.0 ].min } ]
      end
    end

    def days
      counts = UptimeCheck.since(@now.utc.beginning_of_day - (DAYS - 1).days)
        .group(Arel.sql("(checked_at AT TIME ZONE 'UTC')::date")).group(:status).count
      (DAYS - 1).downto(0).map do |offset|
        date = (@now.utc - offset.days).to_date
        by_status = counts.select { |(day, _), _| day == date }.transform_keys(&:last)
        total = by_status.values.sum
        Day.new(date:, checks: total, ok: by_status["ok"].to_i, percent: percent(by_status["ok"].to_i, total))
      end
    end

    # Consecutive non-ok checks (no more than two intervals apart) form one incident, newest first.
    def incidents(limit: 10)
      checks = UptimeCheck.since(@now - DAYS.days).where.not(status: "ok").order(:checked_at).to_a
      groups = checks.slice_when { |a, b| b.checked_at - a.checked_at > 2 * HealthCheckJob::INTERVAL }
      groups.map do |group|
        Incident.new(started_at: group.first.checked_at, ended_at: group.last.checked_at,
                     status: group.any? { _1.status == "down" } ? "down" : "degraded",
                     components: group.flat_map { |check| check.components.select { |_, c| c["status"] != "ok" }.keys }.uniq.sort)
      end.reverse.first(limit)
    end

    private
      def percent(part, total) = total.zero? ? nil : (100.0 * part / total).round(2)
  end
end
