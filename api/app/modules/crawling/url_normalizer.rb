module Crawling
  # Canonical form used to deduplicate URLs (docs/03 §2): lowercase scheme and host, IDN → punycode,
  # default port removed, dot segments resolved, fragment dropped, percent-encoding uppercased with
  # unreserved characters decoded, non-ASCII percent-encoded, tracking parameters removed.
  module UrlNormalizer
    TRACKING_PARAMS = /\A(utm_[a-z_]+|gclid|dclid|fbclid|msclkid|mc_cid|mc_eid|_ga|_gl|yclid)\z/i
    IGNORED_SCHEMES = /\A(javascript|mailto|tel|sms|data|ftp|file|about|blob|ws|wss):/i
    UNRESERVED = /[A-Za-z0-9\-._~]/
    DEFAULT_PORTS = { "http" => 80, "https" => 443 }.freeze

    module_function

    # Resolves an href found on `base_url`; returns nil for links that are not crawlable http(s) URLs.
    def resolve(base_url, href)
      href = href.to_s.strip.gsub(/[\t\n\r]/, "")
      return if href.empty? || href.start_with?("#") || href.match?(IGNORED_SCHEMES)

      absolute = URI.join(base_url, encode_non_ascii(href)).to_s
      normalize(absolute)
    rescue URI::Error, ArgumentError
      nil
    end

    def normalize(url)
      match = encode_non_ascii(url.to_s.strip).match(%r{\A([a-z][a-z0-9+.-]*)://([^/?#]*)([^?#]*)(\?[^#]*)?}i)
      return unless match

      scheme = match[1].downcase
      return unless DEFAULT_PORTS.key?(scheme)

      authority = match[2]
      return if authority.include?("@")

      host, port = split_authority(authority)
      return if host.blank?

      host = to_ascii_host(host)
      port = nil if port.nil? || port == DEFAULT_PORTS[scheme]
      path = normalize_path(match[3])
      query = normalize_query(match[4])

      "#{scheme}://#{host}#{":#{port}" if port}#{path}#{"?#{query}" if query}"
    rescue ArgumentError, SimpleIDN::ConversionError
      nil
    end

    def split_authority(authority)
      if authority.start_with?("[")
        host, rest = authority[1..].split("]", 2)
        port = rest.to_s.delete_prefix(":").presence
        [ "[#{host.downcase}]", port && Integer(port, 10) ]
      else
        host, port = authority.split(":", 2)
        [ host.to_s.downcase.delete_suffix("."), port.presence && Integer(port, 10) ]
      end
    end

    def to_ascii_host(host)
      return host if host.start_with?("[")

      decoded = host.gsub(/%[0-9a-f]{2}/i) { [ _1[1..].hex ].pack("C") }.force_encoding(Encoding::UTF_8)
      decoded.ascii_only? ? decoded : SimpleIDN.to_ascii(decoded).downcase
    end

    def normalize_path(path)
      path = "/" if path.empty?
      remove_dot_segments(normalize_percent(path))
    end

    def normalize_query(query)
      return if query.nil?

      pairs = query.delete_prefix("?").split("&").reject(&:empty?)
      pairs.reject! { |pair| pair.split("=", 2).first.to_s.match?(TRACKING_PARAMS) }
      pairs.empty? ? nil : normalize_percent(pairs.join("&"))
    end

    # Uppercase hex digits; decode escapes of unreserved characters (RFC 3986 §6.2.2).
    def normalize_percent(value)
      value.gsub(/%[0-9a-f]{2}/i) do |escape|
        char = escape[1..].hex.chr
        char.match?(UNRESERVED) ? char : escape.upcase
      end
    end

    def encode_non_ascii(value)
      value.to_s.b.gsub(/[^\x21-\x7e]/n) { |byte| format("%%%02X", byte.ord) }.force_encoding(Encoding::US_ASCII)
    end

    # RFC 3986 §5.2.4; a trailing "." or ".." keeps the path ending in "/".
    def remove_dot_segments(path)
      segments = path.split("/", -1).drop(1)
      output = []
      segments.each_with_index do |segment, index|
        last = index == segments.size - 1
        case segment
        when "." then output << "" if last
        when ".."
          output.pop
          output << "" if last
        else output << segment
        end
      end
      "/" + output.join("/")
    end
  end
end
