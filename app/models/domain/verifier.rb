require "resolv"

# Checks that the user controls a domain (DNS TXT record, file under /.well-known, or meta tag).
# HTTP methods go through SafeHttp and only accept a response served by the domain itself:
# a redirect to another host (e.g. an open redirect) cannot be used to claim the domain.
class Domain::Verifier
  Result = Data.define(:success, :code, :detail)

  AVAILABLE_METHODS = %w[dns_txt html_file meta].freeze
  DNS_TIMEOUT_SECONDS = 3
  META_NAME = "seo-platform-verify".freeze
  MAX_BODY_BYTES = 1024 * 1024

  def initialize(domain, resolver: nil, http_client: nil)
    @domain = domain
    @resolver = resolver
    @http_client = http_client
  end

  def call(method)
    result = check(method)
    record(method, result)
    result
  end

  def self.file_path(domain) = "/.well-known/seo-platform-#{domain.verification_token}.txt"

  def self.meta_tag(domain) = %(<meta name="#{META_NAME}" content="#{domain.verification_token}">)

  private
    def check(method)
      unless Domain::VERIFICATION_METHODS.include?(method)
        return Result.new(false, "invalid_method", I18n.t("domain_verification.invalid_method"))
      end
      unless AVAILABLE_METHODS.include?(method)
        return Result.new(false, "method_not_available", I18n.t("domain_verification.method_not_available"))
      end

      send(:"verify_#{method}")
    end

    def verify_dns_txt
      values = txt_values(@domain.host)
      if values.include?(@domain.txt_record_value)
        success
      else
        failure(I18n.t("domain_verification.txt_missing", value: @domain.txt_record_value, host: @domain.host))
      end
    rescue Resolv::ResolvError, Resolv::ResolvTimeout, SocketError => e
      Result.new(false, "dns_error", I18n.t("domain_verification.dns_error", error: e.class.name.demodulize))
    end

    def verify_html_file
      fetch_from_domain(self.class.file_path(@domain)) do |response|
        if response.success? && response.body.strip == @domain.txt_record_value
          success
        else
          failure(I18n.t("domain_verification.file_mismatch", url: response.url, status: response.status, value: @domain.txt_record_value))
        end
      end
    end

    def verify_meta
      fetch_from_domain("/") do |response|
        content = Nokogiri::HTML(response.body).at_css(%(head meta[name="#{META_NAME}"]))&.[]("content").to_s.strip
        if response.success? && content == @domain.verification_token
          success
        else
          failure(I18n.t("domain_verification.meta_missing", name: META_NAME, url: response.url))
        end
      end
    end

    # Tries https first and falls back to http only when https cannot be reached at all.
    def fetch_from_domain(path)
      errors = []
      %w[https http].each do |scheme|
        response = http_client.get("#{scheme}://#{@domain.host}#{path}")
        final_host = URI.parse(response.url).host
        if final_host != @domain.host
          return failure(I18n.t("domain_verification.cross_host_redirect", url: "#{scheme}://#{@domain.host}#{path}", host: final_host))
        end

        return yield(response)
      rescue SafeHttp::Errors::UnsafeTarget => e
        return Result.new(false, "unsafe_target", e.message)
      rescue SafeHttp::Errors::Base => e
        errors << "#{scheme}: #{e.message}"
      end
      Result.new(false, "fetch_error", I18n.t("domain_verification.fetch_error", errors: errors.join("; ")))
    end

    def success = Result.new(true, "verified", nil)

    def failure(detail) = Result.new(false, "verification_failed", detail)

    # A TXT record may be split into several <=255-byte strings; they are concatenated per record.
    def txt_values(host)
      resolver.getresources(host, Resolv::DNS::Resource::IN::TXT).map { |record| record.strings.join }
    end

    def resolver
      @resolver ||= Resolv::DNS.new.tap { |dns| dns.timeouts = DNS_TIMEOUT_SECONDS }
    end

    def http_client
      @http_client ||= SafeHttp::Client.new(max_bytes: MAX_BODY_BYTES, total_timeout: 15)
    end

    def record(method, result)
      attrs = { last_verification_attempt_at: Time.current, last_verification_error: result.success ? nil : result.code }
      attrs.merge!(verified_at: Time.current, verification_method: method) if result.success
      @domain.update!(attrs)
    end
end
