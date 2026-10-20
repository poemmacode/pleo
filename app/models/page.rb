class Page < ApplicationRecord
  belongs_to :crawl
  belongs_to :crawl_url
  has_one :page_body, dependent: :delete
  has_many :links, foreign_key: :from_page_id, dependent: :delete_all, inverse_of: :from_page
  has_many :structured_data, class_name: "PageStructuredDatum", dependent: :delete_all
  has_many :issues, dependent: :delete_all
  has_many :performance_results, dependent: :delete_all

  def html?
    content_type.to_s.match?(%r{\A(text/html|application/xhtml\+xml)}i)
  end

  def body
    page_body && ActiveSupport::Gzip.decompress(page_body.body_gzip)
  end
end
