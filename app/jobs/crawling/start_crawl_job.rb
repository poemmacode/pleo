class Crawling::StartCrawlJob < ApplicationJob
  queue_as :crawl_control

  def perform(crawl_id)
    crawl = Crawl.find_by(id: crawl_id)
    Crawling::Lifecycle.start(crawl) if crawl
  end
end
