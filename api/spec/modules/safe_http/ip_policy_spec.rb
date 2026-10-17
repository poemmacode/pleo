require "rails_helper"

RSpec.describe SafeHttp::IpPolicy do
  blocked = %w[
    0.0.0.0 10.1.2.3 100.64.0.1 127.0.0.1 127.255.255.254 169.254.169.254 169.254.170.2 172.16.0.1
    172.31.255.255 192.0.0.8 192.0.2.1 192.168.1.1 198.18.0.1 198.51.100.7 203.0.113.9 224.0.0.1
    240.0.0.1 255.255.255.255
    :: ::1 fd00:ec2::254 fc00::1 fe80::1 ff02::1 2001:db8::1 2001:0:4136:e378:8000:63bf:3fff:fdd2
    ::ffff:127.0.0.1 ::ffff:169.254.169.254 ::ffff:10.0.0.1 ::127.0.0.1
    64:ff9b::7f00:1 64:ff9b::a9fe:a9fe 2002:7f00:1::1 2002:a9fe:a9fe::1
  ]
  allowed = %w[1.1.1.1 8.8.8.8 93.184.215.14 172.32.0.1 100.128.0.1 2606:4700:4700::1111 ::ffff:8.8.8.8 64:ff9b::808:808 2002:808:808::1]

  blocked.each { |ip| it("blocks #{ip}") { expect(described_class.blocked?(ip)).to be(true) } }
  allowed.each { |ip| it("allows #{ip}") { expect(described_class.blocked?(ip)).to be(false) } }

  it "only honours the test allowlist in the test environment" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))

    expect { SafeHttp.config.allow_ips_for_tests!([ "127.0.0.1" ]) }.to raise_error(SecurityError)
  end

  it "ignores a populated test allowlist outside the test environment" do
    SafeHttp.config.allow_ips_for_tests!([ "127.0.0.1" ])
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))

    expect(described_class.blocked?("127.0.0.1")).to be(true)
  end
end
