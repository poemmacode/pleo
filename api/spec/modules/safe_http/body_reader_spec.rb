require "rails_helper"

RSpec.describe SafeHttp::BodyReader do
  def read(encoding, payload, max_bytes: 1_000_000, chunk: 7)
    reader = described_class.new(encoding, max_bytes)
    payload.bytes.each_slice(chunk) { reader << _1.pack("C*") }
    reader.finish
    reader.body
  end

  let(:text) { "<html>#{"contenido " * 200}</html>" }

  it "passes identity bodies through" do
    expect(read(nil, text)).to eq(text)
  end

  it "inflates gzip in chunks" do
    expect(read("gzip", ActiveSupport::Gzip.compress(text))).to eq(text)
  end

  it "inflates zlib-wrapped and raw deflate" do
    expect(read("deflate", Zlib::Deflate.deflate(text))).to eq(text)

    raw = Zlib::Deflate.new(Zlib::DEFAULT_COMPRESSION, -Zlib::MAX_WBITS).then { |z| z.deflate(text, Zlib::FINISH) }
    expect(read("deflate", raw)).to eq(text)
  end

  it "stops at the decoded limit" do
    expect { read("gzip", ActiveSupport::Gzip.compress("a" * 100_000), max_bytes: 500) }
      .to raise_error(described_class::LimitReached)
  end
end
