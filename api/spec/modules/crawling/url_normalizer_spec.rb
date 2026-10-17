require "rails_helper"

RSpec.describe Crawling::UrlNormalizer do
  describe ".normalize" do
    {
      "HTTP://Example.COM" => "http://example.com/",
      "https://example.com:443/a" => "https://example.com/a",
      "http://example.com:8080/a" => "http://example.com:8080/a",
      "https://example.com/a/./b/../c" => "https://example.com/a/c",
      "https://example.com/a/b/.." => "https://example.com/a/",
      "https://example.com/a#section" => "https://example.com/a",
      "https://example.com/%7euser/%2fx" => "https://example.com/~user/%2Fx",
      "https://example.com/niño?q=café" => "https://example.com/ni%C3%B1o?q=caf%C3%A9",
      "https://münchen.de/" => "https://xn--mnchen-3ya.de/",
      "https://example.com/p?utm_source=x&id=1&gclid=abc" => "https://example.com/p?id=1",
      "https://example.com/p?utm_medium=a" => "https://example.com/p",
      "https://example.com./" => "https://example.com/"
    }.each do |input, expected|
      it("normalizes #{input}") { expect(described_class.normalize(input)).to eq(expected) }
    end

    [ "ftp://example.com/", "mailto:a@b.com", "https://user:pw@example.com/", "not a url", "https:///nohost" ].each do |input|
      it("rejects #{input.inspect}") { expect(described_class.normalize(input)).to be_nil }
    end
  end

  describe ".resolve" do
    let(:base) { "https://example.com/blog/post/" }

    {
      "../other" => "https://example.com/blog/other",
      "/abs" => "https://example.com/abs",
      "//cdn.example.com/x" => "https://cdn.example.com/x",
      "rel?x=1#y" => "https://example.com/blog/post/rel?x=1",
      " https://Other.com " => "https://other.com/",
      "/ñ" => "https://example.com/%C3%B1"
    }.each do |href, expected|
      it("resolves #{href.inspect}") { expect(described_class.resolve(base, href)).to eq(expected) }
    end

    [ "#top", "javascript:void(0)", "mailto:x@y.z", "tel:123", "data:text/html,x", "" ].each do |href|
      it("ignores #{href.inspect}") { expect(described_class.resolve(base, href)).to be_nil }
    end
  end
end
