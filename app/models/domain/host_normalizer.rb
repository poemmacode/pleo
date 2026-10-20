require "ipaddr"

# Turns user input ("https://Ejemplo.com/ruta", "ÑANDÚ.com.") into a canonical ASCII hostname,
# rejecting anything that is not a public, registrable DNS name.
class Domain::HostNormalizer
  # The message is a code translated under activerecord.errors.models.domain.attributes.host.
  class InvalidHost < StandardError
    def code = message.to_sym
  end

  LABEL = /\A(?!-)[a-z0-9-]{1,63}(?<!-)\z/

  def self.call(input)
    new(input).call
  end

  def initialize(input)
    @input = input.to_s.strip
  end

  def call
    raise InvalidHost, :empty if @input.empty?

    host = extract_host(@input)
    host = host.downcase.delete_suffix(".")
    host = to_ascii(host)

    raise InvalidHost, :ip_address if ip_literal?(host)
    raise InvalidHost, :invalid_hostname unless valid_labels?(host)
    raise InvalidHost, :internal_host if SafeHttp::HostPolicy.blocked_hostname?(host)
    raise InvalidHost, :not_registrable unless PublicSuffix.valid?(host, default_rule: nil)

    host
  end

  private
    def extract_host(input)
      with_scheme = input.match?(%r{\A[a-z][a-z0-9+.-]*://}i) ? input : "http://#{input}"
      uri = URI.parse(with_scheme)
      raise InvalidHost, :unsupported_scheme unless %w[http https].include?(uri.scheme&.downcase)
      raise InvalidHost, :credentials if uri.userinfo
      raise InvalidHost, :port if input.match?(%r{\A(?:[a-z][a-z0-9+.-]*://)?[^/?#]*:\d+}i)
      raise InvalidHost, :invalid_hostname if uri.host.blank?

      uri.host
    rescue URI::InvalidURIError
      # URI rejects non-ASCII hosts; fall back to taking everything before the first path separator.
      bare = input.sub(%r{\A[a-z][a-z0-9+.-]*://}i, "").split(%r{[/?#]}, 2).first.to_s
      raise InvalidHost, :invalid_hostname if bare.empty? || bare.match?(/[@:\s]/)

      bare
    end

    def to_ascii(host)
      host.ascii_only? ? host : SimpleIDN.to_ascii(host)
    rescue StandardError
      raise InvalidHost, :invalid_idn
    end

    # Catches dotted-quad, IPv6 brackets and the integer/hex/octal shorthands browsers accept as IPv4.
    def ip_literal?(host)
      return true if host.start_with?("[")
      return true if (IPAddr.new(host) rescue nil)

      SafeHttp::HostPolicy.numeric_host?(host)
    end

    def valid_labels?(host)
      host.length <= 253 && host.split(".", -1).all? { |label| label.match?(LABEL) }
    end
end
