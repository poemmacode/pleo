class Crawl < ApplicationRecord
  STATUSES = %w[queued running paused completed failed cancelled].freeze
  ACTIVE_STATUSES = %w[queued running].freeze
  FINISHED_STATUSES = %w[completed failed cancelled].freeze

  belongs_to :project
  belongs_to :domain
  has_many :crawl_hosts, dependent: :delete_all
  has_many :crawl_urls, dependent: :delete_all
  has_many :pages, dependent: :delete_all
  has_many :issues, dependent: :delete_all
  has_many :performance_results, dependent: :delete_all
  has_many :reports, dependent: :delete_all

  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: ACTIVE_STATUSES) }

  STATUSES.each { |name| define_method(:"#{name}?") { status == name } }

  def crawl_config
    @crawl_config ||= Crawling::CrawlConfig.from_stored(config)
  end

  # Memoized config objects must not outlive a reload.
  def reload(*)
    @crawl_config = @crawl_scope = nil
    super
  end

  def crawl_scope
    @crawl_scope ||= Crawling::Scope.new(crawl_config.scope, domain.host, crawl_config.start_url)
  end

  def adaptive
    adaptive_rate.present? ? SafeHttp::AdaptiveRate.from_h(adaptive_rate) : SafeHttp::AdaptiveRate.start(current_rps)
  end

  def discovery_cap
    crawl_config.max_pages * 10
  end

  # The most recent earlier crawl of the same domain with a health score, for comparisons.
  def previous_scored
    domain.crawls.where.not(health_score: nil).where(created_at: ...created_at).order(created_at: :desc).first
  end

  def finished?
    FINISHED_STATUSES.include?(status)
  end

  def increment!(**counters)
    self.class.update_counters(id, **counters)
  end
end
