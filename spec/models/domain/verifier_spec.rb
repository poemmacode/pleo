require "rails_helper"

# The verifier asks for https://example.com/...; this sends it to the local test server over plain HTTP.
class LoopbackClient
  def initialize(client, port)
    @client = client
    @port = port
  end

  def get(url)
    uri = URI.parse(url)
    @client.get("http://#{uri.host}:#{@port}#{uri.request_uri}")
  end
end

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

  it "rejects unknown and not-yet-available methods" do
    expect(described_class.new(domain).call("gsc").code).to eq("method_not_available")
    expect(described_class.new(domain).call("bogus").code).to eq("invalid_method")
    expect(domain.reload).not_to be_verified
  end

  describe "HTTP methods" do
    let(:server) { TestHttpServer.new }
    let(:host) { "example.com" }
    let(:client) do
      resolver = StubResolver.new("example.com" => [ "127.0.0.1" ], "www.example.com" => [ "127.0.0.1" ])
      LoopbackClient.new(SafeHttp::Client.new(resolver:, total_timeout: 3), server.port)
    end
    let(:verifier) { described_class.new(domain, http_client: client) }

    before do
      SafeHttp.config.allow_ips_for_tests!([ "127.0.0.1" ])
      SafeHttp.config.allowed_ports = [ server.port ]
    end

    after { server.stop }

    it "verifies with the file under /.well-known" do
      server.route(described_class.file_path(domain), [ 200, {}, "#{domain.txt_record_value}\n" ])

      expect(verifier.call("html_file").success).to be(true)
      expect(domain.reload.verification_method).to eq("html_file")
    end

    it "fails when the file has the wrong content" do
      server.route(described_class.file_path(domain), [ 200, {}, "otra cosa" ])

      expect(verifier.call("html_file")).to have_attributes(success: false, code: "verification_failed")
    end

    it "verifies with the meta tag in the homepage head" do
      server.route("/", [ 200, {}, "<html><head><meta name='seo-platform-verify' content='#{domain.verification_token}'></head></html>" ])

      expect(verifier.call("meta").success).to be(true)
    end

    it "ignores a meta tag with another token" do
      server.route("/", [ 200, {}, "<html><head><meta name='seo-platform-verify' content='nope'></head></html>" ])

      expect(verifier.call("meta").success).to be(false)
    end

    it "does not accept proof served after a redirect to another host" do
      server.route(described_class.file_path(domain), [ 302, { "Location" => "http://www.example.com:#{server.port}/proof" }, "" ])
      server.route("/proof", [ 200, {}, domain.txt_record_value ])

      result = verifier.call("html_file")
      expect(result.success).to be(false)
      expect(result.detail).to include("www.example.com")
    end
  end
end
