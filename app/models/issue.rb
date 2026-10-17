class Issue < ApplicationRecord
  belongs_to :crawl
  belongs_to :page, optional: true
  belongs_to :check_definition, foreign_key: :check_key, primary_key: :key, optional: true
end
