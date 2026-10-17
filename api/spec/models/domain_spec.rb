require "rails_helper"

RSpec.describe Domain do
  it "stores the normalized host and a verification token" do
    domain = create(:domain, host_input: "https://WWW.Example.com/path")

    expect(domain.host).to eq("www.example.com")
    expect(domain.verification_token).to match(/\A[a-zA-Z0-9]{32}\z/)
    expect(domain.txt_record_value).to eq("seo-platform-verify=#{domain.verification_token}")
    expect(domain).not_to be_verified
  end

  it "reports the normalizer's reason as a host error" do
    domain = build(:domain, host_input: "127.0.0.1")

    expect(domain).not_to be_valid
    expect(domain.errors[:host]).to include("no puede ser una dirección IP")
  end

  it "rejects the same host twice in a project but allows it in another project" do
    existing = create(:domain, host_input: "example.com")

    expect(build(:domain, project: existing.project, host_input: "EXAMPLE.com")).not_to be_valid
    expect(build(:domain, host_input: "example.com")).to be_valid
  end
end
