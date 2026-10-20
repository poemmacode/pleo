require "rails_helper"

RSpec.describe Crawling::LinkExtractor do
  it "resolves against <base href>, keeps anchors (or image alt) and rel, and skips non-http links" do
    html = <<~HTML
      <html><head><base href="https://cdn.example.com/root/"><meta name="ROBOTS" content="noindex, nofollow"></head>
      <body>
        <a href="page">  Link   text </a>
        <a href="/abs" rel="nofollow ugc"><img src="x.png" alt="Logo"></a>
        <a href="javascript:void(0)">js</a>
        <map><area href="/area" alt="Zone"></map>
      </body></html>
    HTML

    result = described_class.extract(html, "https://example.com/dir/index.html")

    expect(result.meta_nofollow).to be(true)
    expect(result.links.map(&:to_h)).to eq([
      { url: "https://cdn.example.com/root/page", anchor: "Link text", rel: [] },
      { url: "https://cdn.example.com/abs", anchor: "Logo", rel: %w[nofollow ugc] },
      { url: "https://cdn.example.com/area", anchor: "Zone", rel: [] }
    ])
  end

  it "reads bot-specific robots meta" do
    html = '<meta name="seoplatformbot" content="none">'
    expect(described_class.extract(html, "https://e.com/").meta_nofollow).to be(true)
    expect(described_class.extract("<p>x</p>", "https://e.com/").meta_nofollow).to be(false)
  end
end

RSpec.describe Crawling::SitemapReader do
  it "reads url sets and sitemap indexes, including gzip files and CDATA" do
    urlset = <<~XML
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <url><loc> https://e.com/a?x=1&amp;y=2 </loc></url>
        <url><loc><![CDATA[https://e.com/b]]></loc></url>
      </urlset>
    XML
    index = '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><sitemap><loc>https://e.com/s1.xml</loc></sitemap></sitemapindex>'

    expect(described_class.entries(ActiveSupport::Gzip.compress(urlset)).map(&:to_h)).to eq([
      { kind: :url, loc: "https://e.com/a?x=1&y=2" }, { kind: :url, loc: "https://e.com/b" }
    ])
    expect(described_class.entries(index).map(&:to_h)).to eq([ { kind: :sitemap, loc: "https://e.com/s1.xml" } ])
  end

  it "does not expand external entities" do
    xxe = <<~XML
      <?xml version="1.0"?>
      <!DOCTYPE urlset [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
      <urlset><url><loc>https://e.com/&xxe;</loc></url></urlset>
    XML

    locs = described_class.entries(xxe).map(&:loc)
    expect(locs.join).not_to include("root:")
  end

  it "caps decompressed size" do
    bomb = ActiveSupport::Gzip.compress("<urlset>" + ("<url><loc>https://e.com/x</loc></url>" * 100_000) + "</urlset>")

    expect(described_class.entries(bomb, max_bytes: 10_000).size).to be < 300
  end

  it "returns what it could read from malformed XML" do
    expect(described_class.entries("<urlset><url><loc>https://e.com/a</loc></url><url><loc>").map(&:loc)).to eq([ "https://e.com/a" ])
  end
end
