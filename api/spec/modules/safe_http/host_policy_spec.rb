require "rails_helper"

RSpec.describe SafeHttp::HostPolicy do
  it "blocks loopback, metadata and private-use names" do
    %w[localhost LOCALHOST. a.localhost metadata metadata.google.internal nas.local svc.internal router.lan foo.home.arpa single]
      .each { |host| expect(described_class.blocked_hostname?(host)).to be(true), host }
  end

  it "allows public names" do
    %w[example.com www.example.co.uk xn--mnchen-3ya.de].each do |host|
      expect(described_class.blocked_hostname?(host)).to be(false), host
    end
  end
end
