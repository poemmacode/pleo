class CrawlUrl < ApplicationRecord
  STATES = %w[pending fetching done skipped].freeze
  SKIP_REASONS = %w[robots limit unsafe_host out_of_scope excluded error cancelled].freeze

  belongs_to :crawl
  has_one :page, dependent: :destroy

  def self.hash_url(url) = Digest::SHA256.digest(url)
end
