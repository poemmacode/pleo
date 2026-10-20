module Audit
  # Base class for audit checks. Each check declares its catalog entry with `define` and returns
  # findings: a page (or a URL without a page, or the whole site) plus details for the report.
  # Titles and guidance live in config/locales/checks.*.yml under checks.<key>.
  class Check
    Finding = Data.define(:page_id, :url, :details)
    SEVERITIES = %w[error warning notice].freeze

    class << self
      attr_reader :definition

      def define(key:, category:, severity:, weight:)
        raise ArgumentError, "unknown severity #{severity}" unless SEVERITIES.include?(severity)

        @definition = { key:, category:, severity:, weight: }.freeze
      end

      def key = definition[:key]

      def title = Audit::Check.text(key, :title)

      def description = Audit::Check.text(key, :description)

      def how_to_fix = Audit::Check.text(key, :fix)

      # Findings that describe the whole site (no sitemap, AI bots blocked…) count as full coverage
      # in the health score instead of a share of pages.
      def site_wide! = @site_wide = true

      def site_wide? = @site_wide == true

      # Checks evaluated only on a sample (PageSpeed): coverage is relative to the measured pages.
      def sampled! = @sampled = true

      def sampled? = @sampled == true
    end

    # Localized catalog text (title, description or fix) for a check key.
    def self.text(key, field) = I18n.t("checks.#{key}.#{field}")

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
