module Audit
  # Base class for audit checks. Each check declares its catalog entry with `define` and returns
  # findings: a page (or a URL without a page, or the whole site) plus details for the report.
  class Check
    Finding = Data.define(:page_id, :url, :details)
    SEVERITIES = %w[error warning notice].freeze

    class << self
      attr_reader :definition

      def define(key:, category:, severity:, weight:, title:, description:, fix:)
        raise ArgumentError, "severidad desconocida #{severity}" unless SEVERITIES.include?(severity)

        @definition = { key:, category:, severity:, weight:, title:, description:, how_to_fix: fix }.freeze
      end

      def key = definition[:key]

      # Findings that describe the whole site (no sitemap, AI bots blocked…) count as full coverage
      # in the health score instead of a share of pages.
      def site_wide! = @site_wide = true

      def site_wide? = @site_wide == true
    end

    attr_reader :context

    def initialize(context)
      @context = context
    end

    def findings
      raise NotImplementedError
    end

    private
      def finding(page, details = {}) = Finding.new(page.id, page.url, details)

      def site_finding(details = {}, url: nil) = Finding.new(nil, url, details)
  end
end
