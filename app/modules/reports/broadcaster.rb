module Reports
  # Refreshes the crawl page's export list when a report finishes (same streams as progress).
  module Broadcaster
    module_function

    def call(crawl)
      Crawling::ProgressBroadcaster.each_locale(crawl) do |stream|
        Crawling::ProgressBroadcaster.replace(stream, crawl, :reports, "crawls/reports")
      end
    end
  end
end
