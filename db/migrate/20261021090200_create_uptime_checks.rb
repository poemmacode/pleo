class CreateUptimeChecks < ActiveRecord::Migration[8.0]
  def change
    create_table :uptime_checks do |t|
      t.datetime :checked_at, null: false, index: true
      t.string :status, null: false
      # Per component: { "database" => { "status" => "ok", "ms" => 2 }, ... }
      t.jsonb :components, null: false, default: {}
      t.integer :duration_ms, null: false
    end
    add_check_constraint :uptime_checks, "status IN ('ok', 'degraded', 'down')", name: "uptime_checks_status_check"
  end
end
