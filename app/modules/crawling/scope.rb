module Crawling
  # Which URLs belong to a crawl (docs/03 §2).
  # - domain:    the verified host and any host below it (verifying www.example.com does not cover blog.example.com)
  # - subdomain: only the start URL's host
  # - subfolder: the start URL's host and path prefix (up to the last "/")
  class Scope
    KINDS = %w[domain subdomain subfolder].freeze

    attr_reader :kind, :domain_host, :start_host, :path_prefix

    def initialize(kind, domain_host, start_url)
      @kind = kind
      @domain_host = domain_host
      start = URI.parse(start_url)
      @start_host = start.host
      @path_prefix = start.path.to_s.sub(%r{[^/]*\z}, "").presence || "/"
    end

    def self.host_within?(host, parent) = host == parent || host.end_with?(".#{parent}")

    def include?(url)
      uri = URI.parse(url)
      return false unless uri.host

      case kind
      when "domain" then self.class.host_within?(uri.host, domain_host)
      when "subdomain" then uri.host == start_host
      when "subfolder" then uri.host == start_host && uri.path.to_s.start_with?(path_prefix)
      end
    rescue URI::Error
      false
    end
  end
end
