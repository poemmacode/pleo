require "csv"

module Reports
  # Every finding of the audit, highest priority first.
  class IssuesCsv
    def initialize(crawl)
      @dataset = Dataset.new(crawl)
    end

    def render
      PagesCsv::BOM + CSV.generate do |csv|
        csv << @dataset.issue_headers
        @dataset.each_issue_row { csv << _1 }
      end
    end
  end
end
