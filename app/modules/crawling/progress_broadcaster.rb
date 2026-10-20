module Crawling
  # Pushes the crawl page's live sections over Turbo Streams (Action Cable).
  #
  # Fetch lanes call it after every URL; a Redis SET NX PX key lets through at most one broadcast
  # every THROTTLE_MS per crawl so a fast crawl does not flood browsers. State changes pass
  # force: true and always broadcast, including the audit section.
  #
  # Pages subscribe to [crawl, :progress, locale], so each broadcast is rendered once per language.
  module ProgressBroadcaster
    THROTTLE_MS = 2_000
    KEY_PREFIX = "seo:broadcast:crawl:".freeze

    module_function

    def call(crawl, force: false)
      return unless force || acquire(crawl)

      crawl = Crawl.find(crawl.id) # fresh counters, no cached config/scope
      each_locale(crawl) do |stream|
        replace(stream, crawl, :progress, "crawls/progress")
        replace(stream, crawl, :audit, "crawls/audit") if force
      end
    end

    # Yields the stream name for every available locale, with that locale active.
    def each_locale(crawl)
      I18n.available_locales.each do |locale|
        I18n.with_locale(locale) { yield [ crawl, :progress, locale ] }
      end
    end

    def replace(stream, crawl, section, partial)
      Turbo::StreamsChannel.broadcast_replace_to(
        stream, target: ActionView::RecordIdentifier.dom_id(crawl, section), partial:, locals: { crawl: }
      )
    end

    def acquire(crawl)
      SafeHttp.redis.call("SET", "#{KEY_PREFIX}#{crawl.id}", "1", "NX", "PX", THROTTLE_MS) == "OK"
    end
  end
end
