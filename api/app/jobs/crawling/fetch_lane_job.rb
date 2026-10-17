# One "lane" of a crawl: claims a URL, fetches it, and re-enqueues itself until the frontier is empty
# or the crawl stops running. Pausing or cancelling therefore stops new requests right away.
class Crawling::FetchLaneJob < ApplicationJob
  queue_as :crawl

  def perform(crawl_id)
    crawl = Crawl.find_by(id: crawl_id)
    return unless crawl&.running?

    frontier = Crawling::Frontier.new(crawl)
    crawl_url = frontier.claim
    return Crawling::Lifecycle.maybe_finish(crawl) unless crawl_url

    outcome = Crawling::FetchUrl.new(crawl, crawl_url, frontier:).call
    wait = outcome.is_a?(Array) ? outcome.last : 0
    self.class.set(wait: wait + rand * 0.2).perform_later(crawl_id)
  end
end
