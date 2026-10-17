class Link < ApplicationRecord
  belongs_to :from_page, class_name: "Page"
end
