require "csv"

module Reports
  # Every crawled page with its on-page fields. UTF-8 with BOM so Excel opens accents correctly.
  class PagesCsv
    BOM = "﻿".freeze

    def initialize(crawl)
      @dataset = Dataset.new(crawl)
    end

    def render
      BOM + CSV.generate do |csv|
        csv << @dataset.page_headers
        @dataset.each_page_row { csv << _1 }
      end
    end
  end
end
