# Public status page: a live probe of the app's dependencies plus uptime from the recorded checks.
class StatusController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 60, within: 1.minute, store: RateLimitStore::STORE,
    with: -> { head :too_many_requests }

  def show
    Monitoring::HealthCheckJob.ensure_scheduled
    @live = Monitoring::HealthProbe.call
    @uptime = Monitoring::Uptime.new
    @last_check = UptimeCheck.order(:checked_at).last

    respond_to do |format|
      format.html
      format.json do
        render json: {
          status: @live.status, checked_at: Time.current, components: @live.components,
          uptime: @uptime.windows, last_recorded_check_at: @last_check&.checked_at,
          check_interval_seconds: Monitoring::HealthCheckJob::INTERVAL.to_i
        }, status: @live.status == "down" ? :service_unavailable : :ok
      end
    end
  end
end
