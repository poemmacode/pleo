require "rails_helper"
require "sidekiq/api"

RSpec.describe Monitoring::HealthCheckJob do
  before do
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([ :process ])
    allow(Sidekiq::Queue).to receive(:all).and_return([ instance_double(Sidekiq::Queue, latency: 1.0) ])
    SafeHttp.redis.call("DEL", described_class::LOCK_KEY)
  end

  it "records a check, prunes old ones and schedules the next run once" do
    old = UptimeCheck.create!(checked_at: 100.days.ago, status: "ok", components: {}, duration_ms: 1)

    expect { described_class.perform_now }.to have_enqueued_job(described_class).exactly(:once)

    check = UptimeCheck.sole
    expect(check.status).to eq("ok")
    expect(check.components.keys).to match_array(%w[database redis jobs])
    expect(UptimeCheck.exists?(old.id)).to be(false)
    expect(described_class.ensure_scheduled).to be(false)
  end

  it "reports degraded jobs when no process is running" do
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([])

    described_class.perform_now
    expect(UptimeCheck.sole).to have_attributes(status: "degraded")
    expect(UptimeCheck.sole.components.dig("jobs", "status")).to eq("down")
  end
end
