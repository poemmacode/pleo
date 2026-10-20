class AddScoresToCrawls < ActiveRecord::Migration[8.0]
  def change
    change_table :crawls, bulk: true do |t|
      t.float :health_score
      t.jsonb :category_scores, null: false, default: {}
    end
    add_index :issues, [ :crawl_id, :check_key, :priority_score ]
  end
end
