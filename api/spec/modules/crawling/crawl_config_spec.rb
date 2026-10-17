require "rails_helper"

RSpec.describe Crawling::CrawlConfig do
  let(:verified) { create(:domain, host_input: "example.com", verified_at: Time.current) }
  let(:unverified) { create(:domain, host_input: "rival.com") }

  def build(domain: verified, terms: false, **params)
    described_class.build(params, domain:, terms_accepted: terms).tap(&:validate)
  end

  it "defaults the start URL to the domain homepage" do
    config = build
    expect(config).to be_valid
    expect(config.start_url).to eq("https://example.com/")
  end

  it "accepts start URLs on subdomains of the verified host but not elsewhere" do
    expect(build(start_url: "https://blog.example.com/x")).to be_valid
    expect(build(start_url: "https://example.org/")).not_to be_valid
    expect(build(start_url: "https://notexample.com/")).not_to be_valid
  end

  it "applies verified limits" do
    expect(build(max_pages: 50_000, requests_per_second: 10)).to be_valid
    expect(build(max_pages: 50_001).errors[:max_pages]).to be_present
    expect(build(requests_per_second: 0.1).errors[:requests_per_second]).to be_present
  end

  it "applies stricter limits and requires terms for unverified domains" do
    config = build(domain: unverified, max_pages: 201, requests_per_second: 1)
    expect(config.errors.attribute_names).to include(:max_pages, :requests_per_second, :terms_accepted)
    expect(config.errors[:max_pages].first).to include("sin verificar")

    expect(build(domain: unverified, terms: true, max_pages: 200, requests_per_second: 0.5)).to be_valid
  end

  it "rejects invalid or excessive regex patterns and render_js for now" do
    expect(build(exclude_patterns: [ "(" ]).errors[:exclude_patterns]).to be_present
    expect(build(include_patterns: [ "a" ] * 21).errors[:include_patterns]).to be_present
    expect(build(render_js: true).errors[:render_js]).to be_present
  end

  it "filters paths with include and exclude patterns" do
    config = build(include_patterns: [ "^/blog" ], exclude_patterns: [ "\\?page=" ])
    expect(config.path_allowed?("https://example.com/blog/a")).to be(true)
    expect(config.path_allowed?("https://example.com/blog?page=2")).to be(false)
    expect(config.path_allowed?("https://example.com/shop")).to be(false)
  end

  it "treats a catastrophic regex as not matching instead of hanging" do
    config = build(include_patterns: [ "^(a+)+$" ])
    expect(config).to be_valid

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect(config.path_allowed?("https://example.com/#{"a" * 40}b")).to be(false)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1
  end

  it "round-trips through the stored hash" do
    config = build(max_pages: 10, exclude_patterns: [ "x" ])
    expect(described_class.from_stored(config.to_stored.stringify_keys).to_stored).to eq(config.to_stored)
  end
end

RSpec.describe Crawling::Scope do
  def scope(kind, start = "https://www.example.com/blog/post") = described_class.new(kind, "www.example.com", start)

  it "covers the verified host and hosts below it for the domain scope" do
    expect(scope("domain")).to include("https://www.example.com/x")
    expect(scope("domain")).to include("http://shop.www.example.com/")
    expect(scope("domain")).not_to include("https://example.com/")
    expect(scope("domain")).not_to include("https://evil-www.example.com/")
  end

  it "limits the subdomain scope to the start host" do
    s = scope("subdomain", "https://shop.www.example.com/")
    expect(s).to include("https://shop.www.example.com/a")
    expect(s).not_to include("https://www.example.com/a")
  end

  it "limits the subfolder scope to the start path prefix" do
    expect(scope("subfolder")).to include("https://www.example.com/blog/other")
    expect(scope("subfolder")).not_to include("https://www.example.com/blogroll")
    expect(scope("subfolder")).not_to include("https://www.example.com/")
  end
end
