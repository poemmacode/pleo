require "rails_helper"

RSpec.describe SafeHttp::Client do
  let(:server) { TestHttpServer.new }
  let(:port) { server.port }
  let(:resolver) do
    StubResolver.new(
      "site.example.com" => [ "127.0.0.1" ],
      "other.example.com" => [ "127.0.0.1" ],
      "internal.example.com" => [ "10.0.0.5" ],
      "mixed.example.com" => [ "127.0.0.1", "169.254.169.254" ],
      "metadata-v6.example.com" => [ "fd00:ec2::254" ],
      "rebind.example.com" => [ [ "127.0.0.1" ], [ "127.0.0.2" ] ]
    )
  end
  let(:client) { described_class.new(resolver:, total_timeout: 5, read_timeout: 2) }

  # The test server lives on loopback, so only 127.0.0.1 and its random port are unblocked here.
  before do
    SafeHttp.config.allow_ips_for_tests!([ "127.0.0.1" ])
    SafeHttp.config.allowed_ports = [ 80, 443, port ]
  end

  after { server.stop }

  def url(host, path = "/") = "http://#{host}:#{port}#{path}"

  describe "SSRF guard (docs/03 §3.3)" do
    let(:unblocked_client) { described_class.new(resolver: Resolv::DNS.new) }

    before { SafeHttp.reset_config! }

    [
      "http://127.0.0.1/",
      "http://2130706433/",
      "http://0177.0.0.1/",
      "http://0x7f.0.0.1/",
      "http://0x7f000001/",
      "http://[::1]/",
      "http://[::ffff:127.0.0.1]/",
      "http://[::ffff:7f00:1]/",
      "http://169.254.169.254/latest/meta-data/",
      "http://[fd00:ec2::254]/",
      "http://metadata.google.internal/computeMetadata/v1/",
      "http://localhost/",
      "http://localhost./",
      "http://foo.localhost/",
      "http://printer.local/",
      "http://user:pass@example.com/",
      "gopher://example.com/",
      "file:///etc/passwd",
      "ftp://example.com/",
      "http://example.com:6379/",
      "http://example.com:22/",
      "http://10.0.0.1/",
      "http://192.168.1.1/",
      "http://[fe80::1]/",
      "http://0.0.0.0/"
    ].each do |unsafe|
      it "rejects #{unsafe} before connecting" do
        expect(Net::HTTP).not_to receive(:new)
        expect { unblocked_client.get(unsafe) }.to raise_error(SafeHttp::Errors::UnsafeTarget)
      end
    end

    it "rejects URLs with control characters or non-ASCII" do
      expect { unblocked_client.get("http://example.com/\r\nX: y") }.to raise_error(SafeHttp::Errors::InvalidUrl)
      expect { unblocked_client.get("http://exämple.com/") }.to raise_error(SafeHttp::Errors::InvalidUrl)
    end
  end

  it "rejects a host that resolves to a private address" do
    expect { client.get(url("internal.example.com")) }.to raise_error(SafeHttp::Errors::UnsafeTarget, /10\.0\.0\.5/)
  end

  it "rejects a host whose DNS answer mixes public and blocked addresses" do
    expect { client.get(url("mixed.example.com")) }.to raise_error(SafeHttp::Errors::UnsafeTarget, /169\.254/)
  end

  it "rejects IPv6 metadata addresses returned by DNS" do
    expect { client.get(url("metadata-v6.example.com")) }.to raise_error(SafeHttp::Errors::UnsafeTarget)
  end

  it "connects to the validated IP and sends the original Host header and bot User-Agent" do
    server.route("/hello", [ 200, { "Content-Type" => "text/html" }, "<h1>hola</h1>" ])

    response = client.get(url("site.example.com", "/hello"))

    expect(response).to have_attributes(status: 200, body: "<h1>hola</h1>", ip: "127.0.0.1", truncated: false)
    request = server.received.last
    expect(request[:headers]["host"]).to eq("site.example.com:#{port}")
    expect(request[:headers]["user-agent"]).to start_with("SEOPlatformBot/")
  end

  it "is not affected by DNS rebinding: one lookup per hop, connection to the first answer" do
    server.route("/", [ 200, {}, "ok" ])

    response = client.get(url("rebind.example.com"))

    expect(response.ip).to eq("127.0.0.1")
    expect(resolver.lookups["rebind.example.com"]).to eq(1)
  end

  it "follows redirects, revalidating every hop" do
    server.route("/a", [ 301, { "Location" => "/b" }, "" ])
    server.route("/b", [ 302, { "Location" => url("other.example.com", "/c") }, "" ])
    server.route("/c", [ 200, {}, "final" ])

    response = client.get(url("site.example.com", "/a"))

    expect(response.body).to eq("final")
    expect(response.url).to eq(url("other.example.com", "/c"))
    expect(response.redirect_chain).to eq([
      { url: url("site.example.com", "/a"), status: 301 },
      { url: url("site.example.com", "/b"), status: 302 }
    ])
  end

  it "refuses a redirect from a public site to an internal address" do
    server.route("/go", [ 302, { "Location" => "http://10.0.0.1/admin" }, "" ])

    expect { client.get(url("site.example.com", "/go")) }.to raise_error(SafeHttp::Errors::UnsafeTarget)
  end

  it "refuses a redirect to the cloud metadata endpoint by name" do
    server.route("/go", [ 302, { "Location" => "http://metadata.google.internal/" }, "" ])

    expect { client.get(url("site.example.com", "/go")) }.to raise_error(SafeHttp::Errors::UnsafeTarget)
  end

  it "returns the redirect itself when not following" do
    server.route("/a", [ 301, { "Location" => "/b" }, "" ])

    response = client.get(url("site.example.com", "/a"), follow_redirects: false)

    expect(response.status).to eq(301)
    expect(response.header("Location")).to eq("/b")
  end

  it "stops after the maximum number of redirects" do
    server.route("/loop", [ 302, { "Location" => "/loop" }, "" ])

    expect { described_class.new(resolver:, max_redirects: 3).get(url("site.example.com", "/loop")) }
      .to raise_error(SafeHttp::Errors::TooManyRedirects)
  end

  it "truncates bodies over the size limit instead of reading them whole" do
    server.route("/big", [ 200, {}, "x" * 50_000 ])

    response = described_class.new(resolver:, max_bytes: 1_000).get(url("site.example.com", "/big"))

    expect(response.truncated).to be(true)
    expect(response.body.bytesize).to eq(1_000)
  end

  it "applies the size limit to the decompressed body (gzip bombs)" do
    compressed = ActiveSupport::Gzip.compress("a" * 2_000_000)
    server.route("/bomb", [ 200, { "Content-Encoding" => "gzip" }, compressed ])

    response = described_class.new(resolver:, max_bytes: 10_000).get(url("site.example.com", "/bomb"))

    expect(compressed.bytesize).to be < 10_000
    expect(response.truncated).to be(true)
    expect(response.body.bytesize).to eq(10_000)
  end

  it "times out on slow servers" do
    server.route("/slow", ->(_) { sleep 3; [ 200, {}, "late" ] })

    expect { described_class.new(resolver:, read_timeout: 0.5).get(url("site.example.com", "/slow")) }
      .to raise_error(SafeHttp::Errors::Timeout)
  end

  it "enforces the total deadline across a slowly streamed body" do
    trickle = Enumerator.new { |y| 20.times { y << "x"; sleep 0.2 } }
    server.route("/trickle", [ 200, {}, trickle ])

    expect { described_class.new(resolver:, total_timeout: 1, read_timeout: 1).get(url("site.example.com", "/trickle")) }
      .to raise_error(SafeHttp::Errors::Timeout)
  end

  it "supports HEAD" do
    server.route("/h", [ 200, { "X-Test" => "1" }, "body" ])

    response = client.head(url("site.example.com", "/h"))

    expect(response.status).to eq(200)
    expect(response.header("x-test")).to eq("1")
    expect(server.received.last[:method]).to eq("HEAD")
  end

  it "ignores proxy environment variables" do
    stub_const("ENV", ENV.to_h.merge("http_proxy" => "http://10.0.0.1:3128", "HTTP_PROXY" => "http://10.0.0.1:3128"))
    server.route("/", [ 200, {}, "direct" ])

    expect(client.get(url("site.example.com")).body).to eq("direct")
  end

  it "maps connection failures to SafeHttp errors" do
    closed_port = TCPServer.new("127.0.0.1", 0).then { |s| s.addr[1].tap { s.close } }
    SafeHttp.config.allowed_ports << closed_port

    expect { client.get("http://site.example.com:#{closed_port}/") }.to raise_error(SafeHttp::Errors::Connection)
  end
end
