class PageStructuredDatum < ApplicationRecord
  self.table_name = "page_structured_data"
  belongs_to :page
end
