class CreateCoreTables < ActiveRecord::Migration[8.0]
  def change
    enable_extension "citext"

    create_table :users do |t|
      t.citext :email, null: false, index: { unique: true }
      t.string :password_digest, null: false
      t.timestamps
    end

    # Server-side sessions so a login can be revoked; the cookie only carries the signed id.
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    create_table :projects do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.integer :monthly_api_budget_cents, null: false, default: 0
      t.timestamps
    end

    create_table :domains do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }
      t.string :host, null: false
      t.string :verification_token, null: false
      t.string :verification_method
      t.datetime :verified_at
      t.datetime :last_verification_attempt_at
      t.string :last_verification_error
      t.timestamps
      t.index [ :project_id, :host ], unique: true
    end
  end
end
