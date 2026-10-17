require "rails_helper"

RSpec.describe Crawling::PageExtractor do
  URL = "https://example.com/blog/post".freeze

  def extract(html, url: URL, headers: {}) = described_class.extract(html, url:, headers:)
  def attrs(html, **options) = extract(html, **options).attributes

  # Each fixture is a small HTML document with the fields we expect to be extracted.
  FIXTURES = {
    "basic page" => [
      '<html lang="es-ES"><head><meta charset="UTF-8"><title>  Guía   SEO </title><meta name="description" content=" Una guía "></head><body><h1>Guía</h1></body></html>',
      { title: "Guía SEO", title_count: 1, meta_description: "Una guía", meta_description_count: 1, lang: "es-ES", charset: "utf-8", h1: [ "Guía" ] }
    ],
    "no head elements" => [
      "<p>solo texto</p>",
      { title: nil, title_count: 0, meta_description: nil, meta_description_count: 0, lang: nil, canonical: nil, indexable: true }
    ],
    "multiple titles, svg title ignored" => [
      "<html><head><title>A</title><title>B</title></head><body><svg><title>icono</title></svg></body></html>",
      { title: "A", title_count: 2 }
    ],
    "empty title" => [ "<title>   </title>", { title: nil, title_count: 1 } ],
    "duplicate meta descriptions, case-insensitive name" => [
      '<meta name="Description" content="uno"><meta name="description" content="dos">',
      { meta_description: "uno", meta_description_count: 2 }
    ],
    "self canonical (relative) is indexable" => [
      '<head><link rel="canonical" href="/blog/post"></head>',
      { canonical: URL, canonical_hrefs: [ "/blog/post" ], indexable: true, indexability_reason: nil }
    ],
    "canonical to another page" => [
      '<head><link rel="Canonical" href="https://example.com/otra"></head>',
      { canonical: "https://example.com/otra", indexable: false, indexability_reason: "canonicalized" }
    ],
    "conflicting canonicals" => [
      '<head><link rel="canonical" href="/a"><link rel="canonical" href="/b"></head>',
      { canonical: nil, canonical_hrefs: [ "/a", "/b" ], indexable: false, indexability_reason: "canonical_conflict" }
    ],
    "canonical in body is ignored" => [
      '<html><head></head><body><link rel="canonical" href="/otra"></body></html>',
      { canonical_hrefs: [], canonical: nil }
    ],
    "meta robots noindex" => [
      '<meta name="robots" content="NOINDEX, follow">',
      { noindex: true, nofollow: false, indexable: false, indexability_reason: "noindex", meta_robots: "noindex, follow" }
    ],
    "bot-specific meta none" => [
      '<meta name="SEOPlatformBot" content="none">',
      { noindex: true, nofollow: true }
    ],
    "meta robots for another bot is ignored" => [
      '<meta name="googlebot" content="noindex">',
      { noindex: false, indexable: true }
    ],
    "headings in document order" => [
      "<h2>b</h2><h1> a </h1><h4>c</h4><h1>d</h1>",
      { h1: %w[a d], headings: [ { level: 2, text: "b" }, { level: 1, text: "a" }, { level: 4, text: "c" }, { level: 1, text: "d" } ] }
    ],
    "word count excludes scripts, navigation and footer" => [
      "<body><nav>menú uno dos</nav><script>var x = 1</script><p>Hola, mundo: ¿qué tal? Don't 42</p><footer>pie</footer></body>",
      { word_count: 6 }
    ],
    "images and alt" => [
      '<img src="a.png" alt="A"><img src="b.png" alt=""><img src="c.png">',
      { images_count: 3, images_missing_alt: 1 }
    ],
    "mixed content on https" => [
      '<img src="http://cdn.e.com/a.png"><script src="http://e.com/x.js"></script><link rel="stylesheet" href="http://e.com/s.css"><img src="https://ok.com/b.png"><a href="http://e.com/">enlace normal</a>',
      { mixed_content_count: 3, mixed_content_samples: [ "http://cdn.e.com/a.png", "http://e.com/x.js", "http://e.com/s.css" ] }
    ],
    "hreflang alternates" => [
      '<head><link rel="alternate" hreflang="en" href="/en/post"><link rel="alternate" hreflang="x-default" href="https://example.com/"></head>',
      { hreflang: [ { lang: "en", href: "https://example.com/en/post" }, { lang: "x-default", href: "https://example.com/" } ] }
    ],
    "viewport and charset from http-equiv" => [
      '<head><meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1"><meta name="viewport" content="width=device-width, initial-scale=1"></head>',
      { charset: "iso-8859-1", viewport: "width=device-width, initial-scale=1" }
    ],
    "open graph" => [
      '<meta property="og:title" content="OG"><meta property="og:image" content="https://e.com/i.png"><meta property="og:locale" content="es">',
      { open_graph: { "title" => "OG", "image" => "https://e.com/i.png" } }
    ],
    "malformed html still parses" => [
      "<html><head><title>Roto<body><h1>Sin cerrar<p>texto <b>negrita",
      { title: "Roto", title_count: 1, h1: [ "Sin cerrar" ], word_count: 4 }
    ],
    "links counted" => [ '<a href="/a">a</a><a>sin href</a><a href="#x">x</a>', { links_count: 2 } ]
  }.freeze

  FIXTURES.each do |name, (html, expected)|
    it("extracts #{name}") { expect(attrs(html)).to include(expected) }
  end

  it "has at least 20 fixtures" do
    expect(FIXTURES.size).to be >= 20
  end

  it "reads canonical and robots directives from headers" do
    result = attrs("<title>x</title>", headers: {
      "Link" => [ '<https://example.com/a.css>; rel=preload, <https://example.com/blog/post>; rel="canonical"' ],
      "X-Robots-Tag" => [ "googlebot: noindex", "SEOPlatformBot: nofollow" ]
    })

    expect(result).to include(canonical: URL, noindex: false, nofollow: true, x_robots_tag: "nofollow")
    expect(attrs("<title>x</title>", headers: { "x-robots-tag" => [ "noindex" ] })).to include(noindex: true, indexable: false)
  end

  it "flags a header canonical that disagrees with the HTML one" do
    result = attrs('<head><link rel="canonical" href="/a"></head>', headers: { "link" => [ '<https://example.com/b>; rel="canonical"' ] })

    expect(result).to include(canonical: nil, indexability_reason: "canonical_conflict")
  end

  it "hashes titles and descriptions case-insensitively and computes a simhash" do
    a = attrs("<title>Hola Mundo</title><p>el rápido zorro marrón salta sobre el perro perezoso</p>")
    b = attrs("<title>hola mundo</title><p>el rápido zorro marrón salta sobre el perro perezoso hoy</p>")
    c = attrs("<title>Otro</title><p>contenido completamente distinto sobre recetas de cocina mediterránea</p>")

    expect(a[:title_hash]).to eq(b[:title_hash])
    expect(Crawling::Simhash.distance(a[:text_simhash], b[:text_simhash])).to be < Crawling::Simhash.distance(a[:text_simhash], c[:text_simhash])
    expect(a[:text_simhash]).to be_between(-(2**63), 2**63 - 1)
  end
end

RSpec.describe Crawling::StructuredDataExtractor do
  def extract(html) = described_class.extract(Nokogiri::HTML(html), "https://example.com/")

  it "reads JSON-LD objects, arrays and @graph, with schema prefixes removed" do
    html = <<~HTML
      <script type="application/ld+json">{"@context":"https://schema.org","@type":"Organization","name":"ACME"}</script>
      <script type="application/ld+json">[{"@type":"https://schema.org/WebSite","name":"W"},{"@type":["Product","schema:Thing"]}]</script>
      <script type="application/ld+json"><!--{"@context":"https://schema.org","@graph":[{"@type":"BreadcrumbList"},{"@type":"Person"}]}--></script>
    HTML

    expect(extract(html).map { _1[:types] }).to eq([ %w[Organization], %w[WebSite], %w[Product Thing], %w[BreadcrumbList], %w[Person] ])
  end

  it "records invalid JSON-LD instead of failing" do
    item = extract('<script type="application/ld+json">{"@type": "Product",}</script>').first

    expect(item).to include(syntax: "json-ld", valid_syntax: false)
    expect(item[:validation_errors].first).to start_with("JSON inválido")
  end

  it "reads nested Microdata items" do
    html = <<~HTML
      <div itemscope itemtype="https://schema.org/Product">
        <h1 itemprop="name">Zapatilla</h1>
        <img itemprop="image" src="/z.jpg">
        <div itemprop="offers" itemscope itemtype="https://schema.org/Offer">
          <meta itemprop="priceCurrency" content="EUR"><span itemprop="price" content="59.90">59,90 €</span>
        </div>
        <span itemprop="sku">Z-1</span>
      </div>
    HTML

    item = extract(html).first
    expect(item).to include(syntax: "microdata", types: [ "Product" ])
    expect(item[:data]).to eq(
      "@type" => "Product", "name" => "Zapatilla", "image" => "/z.jpg", "sku" => "Z-1",
      "offers" => { "@type" => "Offer", "priceCurrency" => "EUR", "price" => "59.90" }
    )
  end

  it "collects repeated properties, including nested items, into arrays" do
    html = <<~HTML
      <div itemscope itemtype="https://schema.org/Product"><span itemprop="name">P</span>
        <div itemprop="review" itemscope itemtype="https://schema.org/Review"><span itemprop="author">Ana</span></div>
        <div itemprop="review" itemscope itemtype="https://schema.org/Review"><span itemprop="author">Luis</span></div>
      </div>
    HTML

    expect(extract(html).first[:data]["review"]).to eq([ { "@type" => "Review", "author" => "Ana" }, { "@type" => "Review", "author" => "Luis" } ])
  end

  it "reads RDFa Lite" do
    html = '<div vocab="https://schema.org/" typeof="Event"><span property="name">Concierto</span><time property="startDate" datetime="2026-11-01">1 nov</time></div>'

    expect(extract(html).first).to include(syntax: "rdfa", types: [ "Event" ], data: { "@type" => "Event", "name" => "Concierto", "startDate" => "2026-11-01" })
  end
end
