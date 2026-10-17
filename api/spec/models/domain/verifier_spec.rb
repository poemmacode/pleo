require "rails_helper"

RSpec.describe Domain::Verifier do
  let(:domain) { create(:domain, host_input: "example.com") }

  def resolver_returning(*records)
    resources = records.map { |strings| Resolv::DNS::Resource::IN::TXT.new(*Array(strings)) }
    instance_double(Resolv::DNS).tap do |resolver|
      allow(resolver).to receive(:getresources)
        .with("example.com", Resolv::DNS::Resource::IN::TXT).and_return(resources)
    end
  end

  it "verifies when the TXT record is present" do
    resolver = resolver_returning("v=spf1 -all", domain.txt_record_value)

    result = described_class.new(domain, resolver:).call("dns_txt")

    expect(result.success).to be(true)
    expect(domain.reload).to be_verified
    expect(domain.verification_method).to eq("dns_txt")
    expect(domain.last_verification_error).to be_nil
  end

  it "joins TXT records split into several strings" do
    value = domain.txt_record_value
    resolver = resolver_returning([ value[0, 10], value[10..] ])

    expect(described_class.new(domain, resolver:).call("dns_txt").success).to be(true)
  end

  it "fails when the record is missing and records the attempt" do
    result = described_class.new(domain, resolver: resolver_returning("other")).call("dns_txt")

    expect(result).to have_attributes(success: false, code: "verification_failed")
    expect(domain.reload).not_to be_verified
    expect(domain.last_verification_error).to eq("verification_failed")
    expect(domain.last_verification_attempt_at).to be_present
  end

  it "reports DNS failures without raising" do
    resolver = instance_double(Resolv::DNS)
    allow(resolver).to receive(:getresources).and_raise(Resolv::ResolvTimeout)

    expect(described_class.new(domain, resolver:).call("dns_txt").code).to eq("dns_error")
  end

  it "does not offer methods that need outbound HTTP yet" do
    expect(described_class.new(domain).call("html_file").code).to eq("method_not_available")
    expect(described_class.new(domain).call("bogus").code).to eq("invalid_method")
    expect(domain.reload).not_to be_verified
  end
end
