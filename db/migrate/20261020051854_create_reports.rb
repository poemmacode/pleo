class CreateReports < ActiveRecord::Migration[8.0]
  def change
    # Generated export files. Stored in Postgres because hosted free tiers have ephemeral disks;
    # only the latest report of each kind per crawl is kept.
    create_table :reports do |t|
      t.references :crawl, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false # pages_csv | issues_csv | xlsx | pdf
      t.string :status, null: false, default: "pending" # pending | done | failed
      t.string :filename
      t.string :content_type
      t.binary :data
      t.integer :byte_size
      t.string :error
      t.datetime :generated_at
      t.timestamps
    end
  end
end
