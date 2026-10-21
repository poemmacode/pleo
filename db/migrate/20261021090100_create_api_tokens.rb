class CreateApiTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      # SHA-256 of the token; the token itself is shown once and never stored.
      t.string :token_digest, null: false, index: { unique: true }
      t.string :token_prefix, null: false
      t.datetime :last_used_at
      t.timestamps
    end
  end
end
