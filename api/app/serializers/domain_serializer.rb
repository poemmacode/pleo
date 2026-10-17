module DomainSerializer
  def self.call(domain)
    {
      id: domain.id,
      project_id: domain.project_id,
      host: domain.host,
      verified: domain.verified?,
      verified_at: domain.verified_at,
      verification_method: domain.verification_method,
      verification: {
        available_methods: Domain::Verifier::AVAILABLE_METHODS,
        dns_txt: { name: domain.host, type: "TXT", value: domain.txt_record_value },
        last_attempt_at: domain.last_verification_attempt_at,
        last_error: domain.last_verification_error
      }
    }
  end
end
