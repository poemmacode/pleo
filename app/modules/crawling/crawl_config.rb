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

    attr_accessor :domain, :terms_accepted

    validates :scope, inclusion: { in: Scope::KINDS }
    validates :device, inclusion: { in: DEVICES }
    validates :max_depth, numericality: { only_integer: true, in: 0..MAX_DEPTH }
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
        return errors.add(:start_url, "no es una URL http(s) válida") if start_url.blank?

        host = URI.parse(start_url).host
        errors.add(:start_url, "debe pertenecer a #{domain.host}") unless Scope.host_within?(host, domain.host)
      end

      def within_limits
        unless max_pages.is_a?(Integer) && max_pages.between?(1, limits[:max_pages])
          errors.add(:max_pages, "debe estar entre 1 y #{limits[:max_pages]}#{unverified_note}")
        end
        unless requests_per_second.is_a?(Float) && requests_per_second.between?(MIN_RPS, limits[:max_rps])
          errors.add(:requests_per_second, "debe estar entre #{MIN_RPS} y #{limits[:max_rps]}#{unverified_note}")
        end
      end

      def unverified_note
        domain&.verified? ? "" : " (dominio sin verificar)"
      end

      def patterns_valid
        { include_patterns:, exclude_patterns: }.each do |name, patterns|
          next errors.add(name, "debe ser una lista") unless patterns.is_a?(Array)
          next errors.add(name, "admite como máximo #{MAX_PATTERNS} patrones") if patterns.size > MAX_PATTERNS

          patterns.each do |pattern|
            next errors.add(name, "tiene un patrón demasiado largo") if pattern.to_s.length > MAX_PATTERN_LENGTH

            Regexp.new(pattern.to_s, timeout: PATTERN_TIMEOUT)
          rescue RegexpError
            errors.add(name, "tiene una expresión regular inválida: #{pattern}")
          end
        end
      end

      def render_js_not_available
        errors.add(:render_js, "estará disponible en la iteración 1.1") if render_js
      end

      def terms_for_unverified_domain
        return if domain&.verified? || terms_accepted

        errors.add(:terms_accepted, "debes confirmar que los términos del sitio permiten este rastreo")
      end
  end
end
