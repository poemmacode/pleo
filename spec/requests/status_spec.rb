require "rails_helper"
require "sidekiq/api"

RSpec.describe "Status page" do
  before do
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([ :process ])
    allow(Sidekiq::Queue).to receive(:all).and_return([])
  end

  it "is public and shows live components, uptime and incidents" do
    now = Time.current
    UptimeCheck.create!(checked_at: now - 10.minutes, status: "ok", components: {}, duration_ms: 3)
    UptimeCheck.create!(checked_at: now - 5.minutes, status: "degraded", components: { "redis" => { "status" => "down" } }, duration_ms: 3)

    get status_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("All systems operational", "Database", "Background jobs", "50.00%", "Cache and queues")
  end

  it "answers JSON and 503 when the database is down" do
    allow(ActiveRecord::Base.connection).to receive(:select_value).and_raise(ActiveRecord::ConnectionNotEstablished)

    get status_path(format: :json)

    expect(response).to have_http_status(:service_unavailable)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("down")
    expect(body.dig("components", "database", "status")).to eq("down")
    expect(body.dig("uptime", "24h")).to include("percent" => nil, "checks" => 0)
  end

  it "keeps the scheduled health checks running" do
    SafeHttp.redis.call("DEL", Monitoring::HealthCheckJob::LOCK_KEY)

    expect { get status_path }.to have_enqueued_job(Monitoring::HealthCheckJob)
    expect { get status_path }.not_to have_enqueued_job(Monitoring::HealthCheckJob)
  end
end
