require "rails_helper"

RSpec.describe SafeHttp::Robots::Fetcher do
  let(:server) { TestHttpServer.new }
  let(:resolver) { StubResolver.new("site.example.com" => [ "127.0.0.1" ]) }
  let(:fetcher) { described_class.new(client: SafeHttp::Client.new(resolver:, read_timeout: 1, total_timeout: 3)) }
  let(:origin) { "http://site.example.com:#{server.port}" }

  before do
    SafeHttp.config.allow_ips_for_tests!([ "127.0.0.1" ])
    SafeHttp.config.allowed_ports = [ server.port ]
  end

  after { server.stop }

  it "parses a 200 response" do
    server.route("/robots.txt", [ 200, {}, "User-agent: *\nDisallow: /admin\nSitemap: #{origin}/sitemap.xml" ])

    result = fetcher.fetch(origin)

    expect(result.outcome).to eq(:parsed)
    expect(result.policy).not_to be_allowed("/admin")
    expect(result.sitemaps).to eq([ "#{origin}/sitemap.xml" ])
  end

  it "follows redirects" do
    server.route("/robots.txt", [ 301, { "Location" => "/real-robots.txt" }, "" ])
    server.route("/real-robots.txt", [ 200, {}, "User-agent: *\nDisallow: /" ])

    expect(fetcher.fetch(origin).policy).not_to be_allowed("/x")
  end

  it "allows everything on 4xx" do
    server.route("/robots.txt", [ 404, {}, "" ])

    result = fetcher.fetch(origin)
    expect(result.outcome).to eq(:unavailable)
    expect(result.policy).to be_allowed("/anything")
  end

  [ 429, 500, 503 ].each do |status|
    it "disallows everything on #{status}" do
      server.route("/robots.txt", [ status, {}, "" ])

      result = fetcher.fetch(origin)
      expect(result.outcome).to eq(:unreachable)
      expect(result.policy).not_to be_allowed("/anything")
    end
  end

  it "disallows everything when the server does not answer in time" do
    server.route("/robots.txt", ->(_) { sleep 2; [ 200, {}, "" ] })

    result = fetcher.fetch(origin)
    expect(result.outcome).to eq(:unreachable)
    expect(result.policy).not_to be_allowed("/")
  end

  it "does not swallow SSRF rejections" do
    expect { described_class.new.fetch("http://127.0.0.1/") }.to raise_error(SafeHttp::Errors::UnsafeTarget)
  end
end
