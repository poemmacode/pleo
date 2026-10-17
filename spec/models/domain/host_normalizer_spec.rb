require "rails_helper"

RSpec.describe Domain::HostNormalizer do
  def normalize(input) = described_class.call(input)

  describe "accepted input" do
    {
      "example.com" => "example.com",
      "  Example.COM  " => "example.com",
      "https://www.example.com/blog?x=1" => "www.example.com",
      "http://blog.example.co.uk/" => "blog.example.co.uk",
      "example.com." => "example.com",
      "ñandú.com" => "xn--and-6ma2c.com",
      "https://münchen.de/pfad" => "xn--mnchen-3ya.de"
    }.each do |input, expected|
      it "normalizes #{input.inspect} to #{expected}" do
        expect(normalize(input)).to eq(expected)
      end
    end
  end

  describe "rejected input" do
    [
      "",
      "localhost",
      "foo.localhost",
      "printer.local",
      "db.internal",
      "metadata.google.internal",
      "127.0.0.1",
      "169.254.169.254",
      "2130706433",
      "0x7f.0.0.1",
      "0177.0.0.1",
      "[::1]",
      "http://[fd00:ec2::254]/",
      "user:pass@example.com",
      "https://user@example.com",
      "example.com:8080",
      "ftp://example.com",
      "javascript:alert(1)",
      "com",
      "co.uk",
      "intranet",
      "exa mple.com",
      "-bad.com",
      "example.test",
      "#{"a" * 64}.com"
    ].each do |input|
      it "rejects #{input.inspect}" do
        expect { normalize(input) }.to raise_error(described_class::InvalidHost)
      end
    end
  end
end
