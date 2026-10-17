require "ipaddr"

module SafeHttp
  # Static checks on a URL before any DNS lookup: scheme, credentials, port and host form.
  module UrlValidator
    Target = Data.define(:uri, :host, :port, :literal_ip)

    SCHEMES = %w[http https].freeze

    module_function

    def validate!(url)
      url = url.to_s
      raise Errors::InvalidUrl, "la URL contiene caracteres no permitidos" if url.match?(/[\x00-\x20\x7f]/) || !url.ascii_only?

      uri = URI.parse(url)
      raise Errors::UnsafeTarget, "solo se permiten http y https" unless SCHEMES.include?(uri.scheme&.downcase)
      raise Errors::UnsafeTarget, "la URL no puede incluir credenciales" if uri.userinfo
      raise Errors::InvalidUrl, "la URL no tiene host" if uri.hostname.blank?
      raise Errors::UnsafeTarget, "puerto #{uri.port} no permitido" unless SafeHttp.config.allowed_ports.include?(uri.port)

      host = uri.hostname.downcase.delete_suffix(".")
      Target.new(uri:, host:, port: uri.port, literal_ip: check_host!(host))
    rescue URI::InvalidURIError
      raise Errors::InvalidUrl, "URL mal formada"
    end

    # Returns the IP when the host is an IP literal, nil for a DNS name.
    def check_host!(host)
      if (ip = parse_ip(host))
        raise Errors::UnsafeTarget, "dirección #{ip} bloqueada" if IpPolicy.blocked?(ip)

        ip
      elsif HostPolicy.numeric_host?(host)
        raise Errors::UnsafeTarget, "host numérico ambiguo"
      elsif HostPolicy.blocked_hostname?(host)
        raise Errors::UnsafeTarget, "host interno o reservado"
      end
    end

    def parse_ip(host)
      return unless host.match?(Resolv::IPv4::Regex) || host.match?(Resolv::IPv6::Regex)

      IPAddr.new(host)
    end
  end
end
