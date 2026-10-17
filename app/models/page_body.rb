class PageBody < ApplicationRecord
  self.primary_key = :page_id
  belongs_to :page
end
