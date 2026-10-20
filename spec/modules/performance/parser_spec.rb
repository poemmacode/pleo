require "rails_helper"

RSpec.describe Performance::Parser do
  it "reads lab metrics, CrUX field data and Lighthouse 12 savings" do
    result = described_class.parse(psi_response)

    expect(result).to include(performance_score: 42, lcp_ms: 5200, cls: 0.31, tbt_ms: 640, fcp_ms: 1800, speed_index_ms: 4100,
                              ttfb_ms: 320, field_scope: "url", field_category: "SLOW", field_lcp_ms: 4600, field_cls: 0.12,
                              field_inp_ms: 620)
    expect(result[:opportunities]).to eq([
      { id: "image-delivery-insight", title: "Mejora la entrega de imágenes", savings_ms: 1500 },
      { id: "render-blocking-insight", title: "Solicitudes que bloquean el renderizado", savings_ms: 900 }
    ])
  end

  it "reads Lighthouse 11 opportunities" do
    expect(described_class.parse(psi_response(lighthouse: 11))[:opportunities])
      .to eq([ { id: "unused-javascript", title: "Reduce el JavaScript sin usar", savings_ms: 1200 } ])
  end

  it "marks origin-level field data and handles pages without field data" do
    expect(described_class.parse(psi_response(field: :origin))[:field_scope]).to eq("origin")
    expect(described_class.parse(psi_response(field: nil))).to include(field_scope: nil)
  end

  it "raises on Lighthouse runtime errors" do
    body = { "lighthouseResult" => { "runtimeError" => { "code" => "NO_FCP", "message" => "La página no pintó contenido" } } }

    expect { described_class.parse(body) }.to raise_error(Performance::Client::Error, /no pintó contenido/)
    expect { described_class.parse({}) }.to raise_error(Performance::Client::Error)
  end
end

RSpec.describe Performance::Client do
  let(:http) { instance_double(SafeHttp::Client) }

  it "calls the v5 endpoint with the key, mobile strategy and Spanish locale" do
    expect(http).to receive(:get) do |url|
      uri = URI.parse(url)
      expect(uri.host).to eq("www.googleapis.com")
      expect(URI.decode_www_form(uri.query).to_h).to include("url" => "https://example.com/", "strategy" => "mobile",
                                                              "category" => "performance", "locale" => "es", "key" => "k")
      SafeHttp::Response.new(url:, status: 200, headers: {}, body: '{"lighthouseResult":{}}', ip: nil, redirect_chain: [], truncated: false, elapsed_ms: 1)
    end

    expect(described_class.new(api_key: "k", http:).run("https://example.com/")).to eq("lighthouseResult" => {})
  end

  it "raises with PSI's error message and never the URL (it contains the key)" do
    allow(http).to receive(:get).and_return(
      SafeHttp::Response.new(url: "https://www.googleapis.com/x?key=secret", status: 429, headers: {},
                             body: '{"error":{"message":"Quota exceeded"}}', ip: nil, redirect_chain: [], truncated: false, elapsed_ms: 1)
    )

    expect { described_class.new(api_key: "secret", http:).run("https://example.com/") }
      .to raise_error(Performance::Client::Error, "Quota exceeded")
  end
end

RSpec.describe Performance::Sampler do
  it "collapses numbers and the last slug into URL templates" do
    {
      "https://e.com/" => "/", "https://e.com/blog" => "/blog", "https://e.com/blog/mi-post" => "/blog/*",
      "https://e.com/blog/2024/otro-post" => "/blog/:n/*", "https://e.com/p/123" => "/p/*"
    }.each { |url, template| expect(described_class.template(url)).to eq(template), url }
  end

  it "starts with the start page, then one page per template, then by PageRank" do
    crawl = audit_crawl
    home = audit_page("/", internal_pagerank: 0.3)
    posts = Array.new(3) { audit_page("/blog/post-#{_1}", internal_pagerank: 0.1 - _1 * 0.01) }
    about = audit_page("/about", internal_pagerank: 0.05)
    audit_page("/noindex", internal_pagerank: 0.9, indexable: false)

    expect(described_class.pick(crawl, size: 3)).to eq([ home, posts.first, about ])
    expect(described_class.pick(crawl, size: 10)).to eq([ home, posts.first, about, posts[1], posts[2] ])
  end
end
