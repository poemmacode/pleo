require "rails_helper"

RSpec.describe SafeHttp::Robots::Parser do
  def policy(text, token = "SEOPlatformBot") = described_class.parse(text).policy_for(token)

  it "allows everything when the file is empty or has no matching group" do
    expect(policy("")).to be_allowed("/anything")
    expect(policy("User-agent: Googlebot\nDisallow: /")).to be_allowed("/anything")
  end

  it "uses the * group when no group names the bot" do
    p = policy("User-agent: *\nDisallow: /private/")
    expect(p).not_to be_allowed("/private/x")
    expect(p).to be_allowed("/public")
  end

  it "prefers a group naming the bot over *, matching case-insensitively" do
    p = policy("User-agent: *\nDisallow: /\n\nUser-agent: seoplatformbot\nDisallow: /tmp/")
    expect(p).to be_allowed("/page")
    expect(p).not_to be_allowed("/tmp/a")
  end

  it "accepts a product token with a version in the user-agent line" do
    expect(policy("User-agent: SEOPlatformBot/1.0\nDisallow: /x")).not_to be_allowed("/x")
  end

  it "merges multiple groups for the same agent" do
    p = policy("User-agent: SEOPlatformBot\nDisallow: /a\n\nUser-agent: other\nDisallow: /\n\nUser-agent: SEOPlatformBot\nDisallow: /b")
    expect(p).not_to be_allowed("/a")
    expect(p).not_to be_allowed("/b")
    expect(p).to be_allowed("/c")
  end

  it "shares rules between consecutive user-agent lines" do
    p = policy("User-agent: other\nUser-agent: SEOPlatformBot\nDisallow: /shared")
    expect(p).not_to be_allowed("/shared")
  end

  it "starts a new group when a user-agent line follows rules" do
    p = policy("User-agent: SEOPlatformBot\nDisallow: /a\nUser-agent: other\nDisallow: /b")
    expect(p).to be_allowed("/b")
  end

  it "ignores rules before the first user-agent line" do
    expect(policy("Disallow: /\nUser-agent: *\nDisallow: /x")).to be_allowed("/y")
  end

  it "applies the longest match, with allow winning ties" do
    p = policy("User-agent: *\nDisallow: /folder\nAllow: /folder/page\nDisallow: /folder/page.html\nAllow: /tie\nDisallow: /tie")
    expect(p).not_to be_allowed("/folder/other")
    expect(p).to be_allowed("/folder/page")
    expect(p).not_to be_allowed("/folder/page.html")
    expect(p).to be_allowed("/tie")
  end

  it "supports * wildcards and $ anchors" do
    p = policy("User-agent: *\nDisallow: /*.pdf$\nDisallow: /search*q=\nAllow: /$\nDisallow: /")
    expect(p).to be_allowed("/")
    expect(p).not_to be_allowed("/docs/a.pdf")
    expect(p).not_to be_allowed("/docs/a.html")
    expect(p).not_to be_allowed("/search?x=1&q=seo")

    q = policy("User-agent: *\nDisallow: /*.pdf$")
    expect(q).to be_allowed("/docs/a.pdf?download=1")
    expect(q).not_to be_allowed("/docs/a.pdf")
  end

  it "includes the query string when matching" do
    p = policy("User-agent: *\nDisallow: /*?sessionid=")
    expect(p).not_to be_allowed("https://example.com/page?sessionid=1")
    expect(p).to be_allowed("https://example.com/page?id=1")
  end

  it "treats an empty Disallow as allow-all" do
    expect(policy("User-agent: *\nDisallow:")).to be_allowed("/x")
  end

  it "always allows /robots.txt" do
    expect(policy("User-agent: *\nDisallow: /")).to be_allowed("/robots.txt")
  end

  it "compares percent-encoding case-insensitively and encodes non-ASCII paths" do
    p = policy("User-agent: *\nDisallow: /caf%c3%a9\nDisallow: /niño")
    expect(p).not_to be_allowed("/caf%C3%A9/menu")
    expect(p).not_to be_allowed("/ni%C3%B1o")
    expect(p).not_to be_allowed("https://example.com/ni%c3%b1o/x")
  end

  it "handles comments, blank lines, BOM, CRLF and unknown directives" do
    text = "﻿User-agent: * # everyone\r\nHost: example.com\r\n\r\nDisallow: /x # private\r\nNoindex: /y\r\n"
    p = policy(text)
    expect(p).not_to be_allowed("/x")
    expect(p).to be_allowed("/y")
  end

  it "collects global sitemaps and the matching group's crawl-delay" do
    doc = described_class.parse("Sitemap: https://e.com/a.xml\nUser-agent: *\nCrawl-delay: 2.5\nDisallow: /p\nSitemap: https://e.com/b.xml")
    expect(doc.sitemaps).to eq(%w[https://e.com/a.xml https://e.com/b.xml])
    expect(doc.policy_for.crawl_delay).to eq(2.5)
  end

  it "ignores content past 500 KiB" do
    text = "User-agent: *\n" + ("# filler\n" * 70_000) + "Disallow: /late"
    expect(text.bytesize).to be > described_class::MAX_BYTES
    expect(policy(text)).to be_allowed("/late")
  end
end
