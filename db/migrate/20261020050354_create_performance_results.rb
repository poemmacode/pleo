class CreatePerformanceResults < ActiveRecord::Migration[8.0]
  def change
    # One PageSpeed Insights measurement per sampled page and strategy.
    create_table :performance_results do |t|
      t.references :crawl, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :page, null: false, foreign_key: { on_delete: :cascade }
      t.string :strategy, null: false, default: "mobile"
      # Lab data (Lighthouse)
      t.integer :performance_score
      t.integer :lcp_ms
      t.float :cls
      t.integer :tbt_ms
      t.integer :fcp_ms
      t.integer :speed_index_ms
      t.integer :ttfb_ms
      t.jsonb :opportunities, null: false, default: []
      # Field data (CrUX, 28 days, p75), page-level or origin fallback
      t.string :field_scope # url | origin
      t.string :field_category # FAST | AVERAGE | SLOW
      t.integer :field_lcp_ms
      t.float :field_cls
      t.integer :field_inp_ms
      t.string :error
      t.datetime :fetched_at, null: false
      t.index [ :crawl_id, :page_id, :strategy ], unique: true
    end

    add_column :crawls, :performance_status, :string # nil (not run) | skipped_no_key | done | limited
  end
end
