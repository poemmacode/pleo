module Crawling
  # User-supplied crawl settings with the hard limits from docs/03 §3.1.
  class CrawlConfig
    include ActiveModel::Model
    include ActiveModel::Attributes

    LIMITS = {
      verified: { max_pages: 50_000, max_rps: 10.0 },
      unverified: { max_pages: 2_000, max_rps: 2.0 }
    }.freeze
    # Used when the form leaves a field empty; unverified domains get values within their limits.
    DEFAULTS = {
      verified: { max_pages: 500, requests_per_second: 2.0 },
      unverified: { max_pages: 500, requests_per_second: 1.0 }
    }.freeze
    MIN_RPS = 0.2
    MAX_DEPTH = 50
    MAX_PAGESPEED_SAMPLE = 30
    MAX_PATTERNS = 20
    MAX_PATTERN_LENGTH = 200
    PATTERN_TIMEOUT = 0.05 # seconds; guards against catastrophic backtracking in user regexes
    DEVICES = %w[desktop mobile].freeze

    attribute :start_url, :string
    attribute :scope, :string, default: "domain"
    attribute :max_pages, :integer, default: 500
    attribute :max_depth, :integer, default: 10
    attribute :requests_per_second, :float, default: 2.0
    attribute :include_patterns, default: -> { [] }
    attribute :exclude_patterns, default: -> { [] }
    attribute :device, :string, default: "desktop"
    attribute :render_js, :boolean, default: false
    attribute :use_sitemaps, :boolean, default: true
    attribute :respect_nofollow, :boolean, default: false
    attribute :store_html, :boolean, default: true
    attribute :run_pagespeed, :boolean, default: true
    attribute :pagespeed_sample, :integer, default: 10

    attr_accessor :domain, :terms_accepted

    validates :scope, inclusion: { in: Scope::KINDS }
    validates :device, inclusion: { in: DEVICES }
    validates :max_depth, numericality: { only_integer: true, in: 0..MAX_DEPTH }
    validates :pagespeed_sample, numericality: { only_integer: true, in: 1..MAX_PAGESPEED_SAMPLE }
    validate :start_url_in_domain
    validate :within_limits
    validate :patterns_valid
    validate :render_js_not_available
    validate :terms_for_unverified_domain

    def self.from_stored(hash)
      new(hash.to_h.symbolize_keys.slice(*attribute_names.map(&:to_sym)))
    end

    def self.defaults_for(domain) = DEFAULTS[domain.verified? ? :verified : :unverified]

    def self.build(params, domain:, terms_accepted: false)
      given = params.to_h.symbolize_keys.reject { |_, value| value.is_a?(String) && value.strip.empty? }
      config = from_stored(defaults_for(domain).merge(given))
      config.domain = domain
      config.terms_accepted = ActiveModel::Type::Boolean.new.cast(terms_accepted)
      config.start_url = UrlNormalizer.normalize(config.start_url.presence || "https://#{domain.host}/")
      config
    end

    def limits = LIMITS[domain&.verified? ? :verified : :unverified]

    def to_stored = attributes

    # include/exclude regexes apply to path + query.
    def path_allowed?(url)
      uri = URI.parse(url)
      target = uri.request_uri
      return false if compiled(exclude_patterns).any? { _1.match?(target) }

      include_patterns.empty? || compiled(include_patterns).any? { _1.match?(target) }
    rescue Regexp::TimeoutError, URI::Error
      false
    end

    private
      def compiled(patterns)
        @compiled ||= {}
        @compiled[patterns] ||= patterns.map { Regexp.new(_1, timeout: PATTERN_TIMEOUT) }
      end

      def start_url_in_domain
        return errors.add(:start_url, :invalid_url) if start_url.blank?

        host = URI.parse(start_url).host
        errors.add(:start_url, :outside_domain, host: domain.host) unless Scope.host_within?(host, domain.host)
      end

      def within_limits
        unless max_pages.is_a?(Integer) && max_pages.between?(1, limits[:max_pages])
          errors.add(:max_pages, limit_error, min: 1, max: limits[:max_pages])
        end
        unless requests_per_second.is_a?(Float) && requests_per_second.between?(MIN_RPS, limits[:max_rps])
          errors.add(:requests_per_second, limit_error, min: MIN_RPS, max: limits[:max_rps])
        end
      end

      # Unverified domains get a message that explains their lower limits.
      def limit_error = domain&.verified? ? :out_of_range : :out_of_range_unverified

      def patterns_valid
        { include_patterns:, exclude_patterns: }.each do |name, patterns|
          next errors.add(name, :not_a_list) unless patterns.is_a?(Array)
          next errors.add(name, :too_many_patterns, count: MAX_PATTERNS) if patterns.size > MAX_PATTERNS

          patterns.each do |pattern|
            next errors.add(name, :pattern_too_long, count: MAX_PATTERN_LENGTH) if pattern.to_s.length > MAX_PATTERN_LENGTH

            Regexp.new(pattern.to_s, timeout: PATTERN_TIMEOUT)
          rescue RegexpError
            errors.add(name, :invalid_regex, pattern:)
          end
        end
      end

      def render_js_not_available
        errors.add(:render_js, :not_available) if render_js
      end

      def terms_for_unverified_domain
        return if domain&.verified? || terms_accepted

        errors.add(:terms_accepted, :required)
      end
  end
end
