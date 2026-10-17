require "ipaddr"

# Turns user input ("https://Ejemplo.com/ruta", "ÑANDÚ.com.") into a canonical ASCII hostname,
# rejecting anything that is not a public, registrable DNS name.
class Domain::HostNormalizer
  class InvalidHost < StandardError; end

  LABEL = /\A(?!-)[a-z0-9-]{1,63}(?<!-)\z/

  def self.call(input)
    new(input).call
  end

  def initialize(input)
    @input = input.to_s.strip
  end

  def call
    raise InvalidHost, "no puede estar vacío" if @input.empty?

    host = extract_host(@input)
    host = host.downcase.delete_suffix(".")
    host = to_ascii(host)

    raise InvalidHost, "no puede ser una dirección IP" if ip_literal?(host)
    raise InvalidHost, "no es un nombre de host válido" unless valid_labels?(host)
    raise InvalidHost, "es un host interno o reservado" if SafeHttp::HostPolicy.blocked_hostname?(host)
    raise InvalidHost, "no pertenece a un dominio público registrable" unless PublicSuffix.valid?(host, default_rule: nil)

    host
  end

  private
    def extract_host(input)
      with_scheme = input.match?(%r{\A[a-z][a-z0-9+.-]*://}i) ? input : "http://#{input}"
      uri = URI.parse(with_scheme)
      raise InvalidHost, "solo se admiten http y https" unless %w[http https].include?(uri.scheme&.downcase)
      raise InvalidHost, "no debe incluir usuario ni contraseña" if uri.userinfo
      raise InvalidHost, "no debe incluir un puerto" if input.match?(%r{\A(?:[a-z][a-z0-9+.-]*://)?[^/?#]*:\d+}i)
      raise InvalidHost, "no es un nombre de host válido" if uri.host.blank?

      uri.host
    rescue URI::InvalidURIError
      # URI rejects non-ASCII hosts; fall back to taking everything before the first path separator.
      bare = input.sub(%r{\A[a-z][a-z0-9+.-]*://}i, "").split(%r{[/?#]}, 2).first.to_s
      raise InvalidHost, "no es un nombre de host válido" if bare.empty? || bare.match?(/[@:\s]/)

      bare
    end

    def to_ascii(host)
      host.ascii_only? ? host : SimpleIDN.to_ascii(host)
    rescue StandardError
      raise InvalidHost, "no es un nombre de dominio internacional válido"
    end

    # Catches dotted-quad, IPv6 brackets and the integer/hex/octal shorthands browsers accept as IPv4.
    def ip_literal?(host)
      return true if host.start_with?("[")
      return true if (IPAddr.new(host) rescue nil)

      host.split(".").all? { |label| label.match?(/\A(0x[0-9a-f]*|\d+)\z/) }
    end

    def valid_labels?(host)
      host.length <= 253 && host.split(".", -1).all? { |label| label.match?(LABEL) }
    end
end
