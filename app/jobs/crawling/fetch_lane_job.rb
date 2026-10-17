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
    Crawling::ProgressBroadcaster.call(crawl)
    # Re-enqueue right away: a scheduled job only starts on Sidekiq's next poll (~5 s), which would
    # throttle the crawl far below its rate. FetchUrl already waits in-process for short slots.
    if outcome.is_a?(Array)
      self.class.set(wait: outcome.last).perform_later(crawl_id)
    else
      self.class.perform_later(crawl_id)
    end
  end
end
