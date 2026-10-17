module Crawling
  # Pushes the crawl page's live sections over Turbo Streams (Action Cable).
  #
  # Fetch lanes call it after every URL; a Redis SET NX PX key lets through at most one broadcast
  # every THROTTLE_MS per crawl so a fast crawl does not flood browsers. State changes pass
  # force: true and always broadcast, including the audit section.
  module ProgressBroadcaster
    THROTTLE_MS = 2_000
    KEY_PREFIX = "seo:broadcast:crawl:".freeze

    module_function

    def call(crawl, force: false)
      return unless force || acquire(crawl)

      crawl = Crawl.find(crawl.id) # fresh counters, no cached config/scope
      Turbo::StreamsChannel.broadcast_replace_to(
        [ crawl, :progress ], target: ActionView::RecordIdentifier.dom_id(crawl, :progress),
        partial: "crawls/progress", locals: { crawl: }
      )
      return unless force

      Turbo::StreamsChannel.broadcast_replace_to(
        [ crawl, :progress ], target: ActionView::RecordIdentifier.dom_id(crawl, :audit),
        partial: "crawls/audit", locals: { crawl: }
      )
    end

    def acquire(crawl)
      SafeHttp.redis.call("SET", "#{KEY_PREFIX}#{crawl.id}", "1", "NX", "PX", THROTTLE_MS) == "OK"
    end
  end
end
