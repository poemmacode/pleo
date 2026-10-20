module Reports
  # Refreshes the crawl page's export list when a report finishes (same stream as progress).
  module Broadcaster
    module_function

    def call(crawl)
      Turbo::StreamsChannel.broadcast_replace_to(
        [ crawl, :progress ], target: ActionView::RecordIdentifier.dom_id(crawl, :reports),
        partial: "crawls/reports", locals: { crawl: }
      )
    end
  end
end
