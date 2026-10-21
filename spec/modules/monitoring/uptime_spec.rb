require "rails_helper"

RSpec.describe Monitoring::Uptime do
  let(:now) { Time.utc(2026, 10, 21, 12) }

  def check(at, status, components = {}) = UptimeCheck.create!(checked_at: at, status:, components:, duration_ms: 1)

  it "computes uptime and coverage per window, ignoring periods without checks" do
    3.times { |i| check(now - (i * 5).minutes, "ok") }
    check(now - 2.days, "degraded")

    windows = described_class.new(now:).windows
    expect(windows["24h"]).to include(percent: 100.0, checks: 3)
    expect(windows["24h"][:coverage]).to be_within(0.1).of(1.04)
    expect(windows["7d"]).to include(percent: 75.0, checks: 4)
  end

  it "builds 30 daily bars with no data for empty days" do
    check(now - 1.hour, "ok")
    check(now - 2.hours, "down")

    days = described_class.new(now:).days
    expect(days.size).to eq(30)
    expect(days.last).to have_attributes(date: now.to_date, checks: 2, percent: 50.0)
    expect(days.first.percent).to be_nil
  end

  it "groups consecutive failed checks into incidents, newest first" do
    check(now - 3.hours, "degraded", { "redis" => { "status" => "down" } })
    check(now - 3.hours + 5.minutes, "down", { "database" => { "status" => "down" } })
    check(now - 1.hour, "degraded", { "jobs" => { "status" => "degraded" } })

    incidents = described_class.new(now:).incidents
    expect(incidents.map(&:status)).to eq(%w[degraded down])
    expect(incidents.last.components).to eq(%w[database redis])
    expect(incidents.last.ended_at - incidents.last.started_at).to eq(5.minutes)
  end
end
