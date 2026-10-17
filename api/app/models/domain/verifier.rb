require "resolv"

# Checks that the user controls a domain. Only DNS TXT is available until SafeHttp (Épica A) exists,
# because the file and meta-tag methods require fetching URLs supplied by the user.
class Domain::Verifier
  Result = Data.define(:success, :code, :detail)

  AVAILABLE_METHODS = %w[dns_txt].freeze
  DNS_TIMEOUT_SECONDS = 3

  def initialize(domain, resolver: nil)
    @domain = domain
    @resolver = resolver
  end

  def call(method)
    result = check(method)
    record(method, result)
    result
  end

  private
    def check(method)
      unless Domain::VERIFICATION_METHODS.include?(method)
        return Result.new(false, "invalid_method", "Método de verificación desconocido")
      end
      unless AVAILABLE_METHODS.include?(method)
        return Result.new(false, "method_not_available", "Este método estará disponible en una próxima versión; usa dns_txt")
      end

      verify_dns_txt
    end

    def verify_dns_txt
      values = txt_values(@domain.host)
      if values.include?(@domain.txt_record_value)
        Result.new(true, "verified", nil)
      else
        Result.new(false, "verification_failed", "No se encontró el registro TXT #{@domain.txt_record_value} en #{@domain.host}")
      end
    rescue Resolv::ResolvError, Resolv::ResolvTimeout, SocketError => e
      Result.new(false, "dns_error", "Error al consultar DNS: #{e.class.name.demodulize}")
    end

    # A TXT record may be split into several <=255-byte strings; they are concatenated per record.
    def txt_values(host)
      resolver.getresources(host, Resolv::DNS::Resource::IN::TXT).map { |record| record.strings.join }
    end

    def resolver
      @resolver ||= Resolv::DNS.new.tap { |dns| dns.timeouts = DNS_TIMEOUT_SECONDS }
    end

    def record(method, result)
      attrs = { last_verification_attempt_at: Time.current, last_verification_error: result.success ? nil : result.code }
      attrs.merge!(verified_at: Time.current, verification_method: method) if result.success
      @domain.update!(attrs)
    end
end
