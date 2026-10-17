require "rails_helper"

RSpec.describe "Audit checks" do
  C = Audit::Checks

  # [check, attributes that trigger it, attributes that must not trigger it]
  PAGE_CASES = [
    [ C::Crawlability::Http4xx, { status_code: 404 }, { status_code: 200 } ],
    [ C::Crawlability::Http5xx, { status_code: 503 }, { status_code: 404 } ],
    [ C::Crawlability::FetchFailed, { status_code: nil, fetch_error: "Timeout: Net::ReadTimeout" }, { status_code: nil, fetch_error: "Tls: certificate verify failed" } ],
    [ C::Crawlability::RedirectTemporary, { status_code: 302, redirect_url: "https://example.com/x", inlinks_count: 2 }, { status_code: 301, redirect_url: "https://example.com/x", inlinks_count: 2 } ],
    [ C::Crawlability::SitemapNon200, { in_sitemap: true, status_code: 404 }, { in_sitemap: false, status_code: 404 } ],
    [ C::Crawlability::SitemapNoindex, { in_sitemap: true, indexable: false, noindex: true, indexability_reason: "noindex" }, { in_sitemap: true } ],
    [ C::Crawlability::Orphan, { in_sitemap: true, inlinks_count: 0 }, { in_sitemap: true, inlinks_count: 1 } ],
    [ C::Crawlability::Deep, { depth: 5 }, { depth: 4 } ],
    [ C::Indexability::Noindex, { noindex: true, indexable: false }, { noindex: false } ],
    [ C::Indexability::CanonicalMissing, { canonical: nil, canonical_hrefs: [] }, { canonical: nil, canonical_hrefs: [], noindex: true } ],
    [ C::Indexability::CanonicalMultiple, { canonical: nil, canonical_hrefs: %w[/a /b], indexability_reason: "canonical_conflict" }, {} ],
    [ C::Indexability::CanonicalInvalid, { canonical_hrefs: [ "/relativa" ] }, {} ],
    [ C::Indexability::HreflangInvalidCode, { hreflang: [ { "lang" => "es_ES", "href" => "x" }, { "lang" => "sp", "href" => "y" } ] },
      { hreflang: [ { "lang" => "es-MX", "href" => "x" }, { "lang" => "x-default", "href" => "y" }, { "lang" => "zh-Hant-TW", "href" => "z" } ] } ],
    [ C::Metadata::TitleMissing, { title: nil }, {} ],
    [ C::Metadata::TitleTooLong, { title: "T" * 61 }, { title: "T" * 60 } ],
    [ C::Metadata::TitleTooShort, { title: "Inicio" }, { title: "T" * 15 } ],
    [ C::Metadata::TitleMultiple, { title_count: 2 }, { title_count: 1 } ],
    [ C::Metadata::DescriptionMissing, { meta_description: nil }, { meta_description: nil, indexable: false } ],
    [ C::Metadata::DescriptionLength, { meta_description: "D" * 161 }, { meta_description: "D" * 70 } ],
    [ C::Content::H1Missing, { h1: [] }, {} ],
    [ C::Content::H1Multiple, { h1: %w[a b] }, {} ],
    [ C::Content::HeadingsSkipped, { headings: [ { "level" => 1 }, { "level" => 3 } ] }, { headings: [ { "level" => 1 }, { "level" => 2 }, { "level" => 3 }, { "level" => 2 } ] } ],
    [ C::Content::H1EqualsTitle, { title: "Guía de SEO técnico", h1: [ "guía de seo técnico" ] }, {} ],
    [ C::Content::Thin, { word_count: 150 }, { word_count: 150, indexable: false } ],
    [ C::Content::ImagesMissingAlt, { images_missing_alt: 2 }, {} ],
    [ C::Links::TooMany, { links_count: 301 }, { links_count: 300 } ],
    [ C::Https::NotUsed, { path: "http://example.com/plano" }, {} ],
    [ C::Https::MixedContent, { mixed_content_count: 1, mixed_content_samples: [ "http://cdn/x.js" ] }, {} ],
    [ C::Https::CertInvalid, { status_code: nil, fetch_error: "Tls: certificate has expired" }, { status_code: nil, fetch_error: "Timeout: x" } ],
    [ C::MobilePerformance::ViewportMissing, { viewport: nil }, {} ],
    [ C::MobilePerformance::PageTooLarge, { content_length: 3_000_000 }, { content_length: 2_000_000 } ],
    [ C::MobilePerformance::SlowResponse, { response_ms: 1600 }, { response_ms: 1500 } ]
  ].freeze

  PAGE_CASES.each do |check, bad, good|
    describe check.key do
      it "flags a page with #{bad.except(:path).keys.join(", ")}" do
        audit_page(bad[:path] || "/bad", **bad.except(:path))
        expect(flagged_urls(check)).to eq([ bad[:path] || "https://example.com/bad" ])
      end

      it "does not flag a page without the problem" do
        audit_page("/good", **good)
        expect(findings_for(check)).to be_empty
      end
    end
  end

  it "covers every check in the catalog with a spec" do
    covered = PAGE_CASES.map(&:first) + [
      C::Crawlability::RedirectChain, C::Crawlability::RedirectLoop, C::Crawlability::RobotsBlockedLinked,
      C::Crawlability::SitemapMissing, C::Indexability::CanonicalToNon200, C::Indexability::CanonicalToNoindex,
      C::Indexability::CanonicalChain, C::Indexability::HreflangNoReturn, C::Metadata::TitleDuplicate,
      C::Metadata::DescriptionDuplicate, C::Content::NearDuplicate, C::Links::InternalBroken, C::Links::ExternalBroken,
      C::Links::InternalNofollow, C::Links::ToRedirect, C::Https::HttpLinks, C::StructuredData::InvalidJson,
      C::StructuredData::UnknownType, C::StructuredData::MissingRequired, C::StructuredData::None,
      C::AiSearch::BotsBlocked, C::AiSearch::LlmsTxtMissing
    ]
    expect(Audit::Catalog::CHECKS - covered).to be_empty
  end

  it "has unique keys and Spanish texts for every definition" do
    definitions = Audit::Catalog.definitions
    expect(definitions.map { _1[:key] }.uniq.size).to eq(definitions.size)
    expect(definitions).to all(include(:title, :description, :how_to_fix))
  end

  describe "redirects" do
    it "detects chains and loops through crawled pages" do
      audit_page("/a", status_code: 301, redirect_url: "https://example.com/b")
      audit_page("/b", status_code: 301, redirect_url: "https://example.com/c")
      audit_page("/c")
      audit_page("/x", status_code: 302, redirect_url: "https://example.com/y")
      audit_page("/y", status_code: 302, redirect_url: "https://example.com/x")
      audit_page("/single", status_code: 301, redirect_url: "https://example.com/c")

      chain = findings_for(C::Crawlability::RedirectChain)
      expect(chain.map(&:url)).to eq([ "https://example.com/a" ])
      expect(chain.first.details).to include(hops: 2)
      expect(flagged_urls(C::Crawlability::RedirectLoop)).to contain_exactly("https://example.com/x", "https://example.com/y")
    end
  end

  describe "canonical targets" do
    it "flags canonicals to non-200, noindex and canonicalised pages" do
      audit_page("/gone", status_code: 404)
      audit_page("/hidden", noindex: true, indexable: false)
      audit_page("/middle", canonical: "https://example.com/final")
      audit_page("/to-gone", canonical: "https://example.com/gone", indexable: false)
      audit_page("/to-hidden", canonical: "https://example.com/hidden", indexable: false)
      audit_page("/to-middle", canonical: "https://example.com/middle", indexable: false)
      audit_page("/to-uncrawled", canonical: "https://example.com/elsewhere", indexable: false)

      expect(flagged_urls(C::Indexability::CanonicalToNon200)).to eq([ "https://example.com/to-gone" ])
      expect(flagged_urls(C::Indexability::CanonicalToNoindex)).to eq([ "https://example.com/to-hidden" ])
      expect(flagged_urls(C::Indexability::CanonicalChain)).to eq([ "https://example.com/to-middle" ])
    end
  end

  describe "hreflang return links" do
    it "flags alternates that do not link back" do
      audit_page("/es", hreflang: [ { "lang" => "en", "href" => "https://example.com/en" } ])
      audit_page("/en", hreflang: [])
      audit_page("/fr", hreflang: [ { "lang" => "de", "href" => "https://example.com/de" } ])
      audit_page("/de", hreflang: [ { "lang" => "fr", "href" => "https://example.com/fr" } ])

      findings = findings_for(C::Indexability::HreflangNoReturn)
      expect(findings.map(&:url)).to eq([ "https://example.com/es" ])
      expect(findings.first.details).to eq(alternates_without_return: [ "https://example.com/en" ])
    end
  end

  describe "duplicates" do
    it "groups indexable pages with the same title or description" do
      same = Digest::SHA256.digest("igual")
      audit_page("/a", title_hash: same, description_hash: same)
      audit_page("/b", title_hash: same)
      audit_page("/c", title_hash: same, indexable: false)
      audit_page("/d", title_hash: Digest::SHA256.digest("otro"), description_hash: same)

      expect(flagged_urls(C::Metadata::TitleDuplicate)).to eq(%w[https://example.com/a https://example.com/b])
      expect(findings_for(C::Metadata::TitleDuplicate).first.details).to eq(count: 2, others: [ "https://example.com/b" ])
      expect(flagged_urls(C::Metadata::DescriptionDuplicate)).to eq(%w[https://example.com/a https://example.com/d])
    end

    it "finds near-duplicate content among substantial indexable pages" do
      hash = 0x0123_4567_89ab_cdef
      audit_page("/a", text_simhash: hash)
      audit_page("/b", text_simhash: hash ^ 0b101)
      audit_page("/c", text_simhash: hash ^ 0b1, word_count: 20)
      audit_page("/d", text_simhash: ~hash)

      expect(flagged_urls(C::Content::NearDuplicate)).to eq(%w[https://example.com/a https://example.com/b])
    end
  end

  describe "link checks" do
    it "flags broken, nofollow, redirected and http internal links per source page" do
      home = audit_page("/")
      audit_page("/rota", status_code: 404)
      audit_page("/vieja", status_code: 301, redirect_url: "https://example.com/")
      audit_page("/ok")
      audit_link(home, "https://example.com/rota")
      audit_link(home, "https://example.com/vieja")
      audit_link(home, "https://example.com/ok", rel: [ "nofollow" ])
      audit_link(home, "http://example.com/ok")
      audit_link(home, "https://example.com/ok")

      broken = findings_for(C::Links::InternalBroken)
      expect(broken.map(&:url)).to eq([ "https://example.com/" ])
      expect(broken.first.details).to eq(count: 1, targets: [ "https://example.com/rota" ])
      expect(findings_for(C::Links::ToRedirect).first.details[:targets]).to eq([ "https://example.com/vieja" ])
      expect(findings_for(C::Links::InternalNofollow).first.details[:targets]).to eq([ "https://example.com/ok" ])
      expect(findings_for(C::Https::HttpLinks).first.details[:targets]).to eq([ "http://example.com/ok" ])
    end

    it "flags external links that failed the check, but not rate limits or robots blocks" do
      home = audit_page("/")
      { "https://a.net/404" => [ 404, nil ], "https://b.net/x" => [ nil, "resolution" ], "https://c.net/" => [ 429, nil ],
        "https://d.net/" => [ nil, "robots" ], "https://e.net/" => [ 200, nil ] }.each do |url, (status, error)|
        audit_link(home, url, internal: false)
        ExternalLinkCheck.create!(crawl: audit_crawl, url:, url_hash: CrawlUrl.hash_url(url), status_code: status, error:, checked_at: Time.current)
      end

      expect(findings_for(C::Links::ExternalBroken).first.details).to eq(count: 2, targets: %w[https://a.net/404 https://b.net/x])
    end

    it "lists linked URLs blocked by robots.txt" do
      home = audit_page("/")
      CrawlUrl.create!(crawl: audit_crawl, url: "https://example.com/privado", url_hash: CrawlUrl.hash_url("https://example.com/privado"),
                       source: "link", state: "skipped", skip_reason: "robots")
      audit_link(home, "https://example.com/privado")

      findings = findings_for(C::Crawlability::RobotsBlockedLinked)
      expect(findings.map { [ _1.page_id, _1.url, _1.details ] }).to eq([ [ nil, "https://example.com/privado", { linked_from_pages: 1 } ] ])
    end
  end

  describe "structured data" do
    def add_schema(page, valid: true, errors: [])
      PageStructuredDatum.create!(page:, syntax: "json-ld", types: [ "Product" ], valid_syntax: valid, validation_errors: errors)
    end

    it "reports invalid JSON, unknown types, missing properties and pages without markup" do
      add_schema(audit_page("/roto"), valid: false, errors: [ "JSON inválido" ])
      add_schema(audit_page("/errata"), errors: [ { "code" => "unknown_type", "type" => "Prodcut" } ])
      add_schema(audit_page("/incompleto"), errors: [ { "code" => "missing_required", "type" => "Product", "property" => "name" } ])
      add_schema(audit_page("/bien"))
      audit_page("/sin-marcado")

      expect(flagged_urls(C::StructuredData::InvalidJson)).to eq([ "https://example.com/roto" ])
      expect(findings_for(C::StructuredData::UnknownType).first.details).to eq(types: [ "Prodcut" ])
      expect(findings_for(C::StructuredData::MissingRequired).first.details).to eq(missing: [ "Product · name" ])
      expect(flagged_urls(C::StructuredData::None)).to eq([ "https://example.com/sin-marcado" ])
    end
  end

  describe "site checks" do
    it "reports a missing sitemap only when discovery ran and found none" do
      audit_crawl.update!(sitemaps: [ { "url" => "https://example.com/sitemap.xml", "status" => 404 } ])
      expect(findings_for(C::Crawlability::SitemapMissing).size).to eq(1)

      audit_crawl.update!(sitemaps: [ { "url" => "https://example.com/sitemap.xml", "status" => 200 } ])
      expect(findings_for(C::Crawlability::SitemapMissing)).to be_empty

      audit_crawl.update!(sitemap_status: "skipped", sitemaps: [])
      expect(findings_for(C::Crawlability::SitemapMissing)).to be_empty
    end

    it "reports AI crawlers blocked and a missing llms.txt" do
      audit_crawl.update!(site_facts: { "ai_bots_blocked" => %w[GPTBot CCBot], "llms_txt" => { "url" => "https://example.com/llms.txt", "present" => false, "status" => 404 } })

      expect(findings_for(C::AiSearch::BotsBlocked).first.details).to eq(bots: %w[GPTBot CCBot])
      expect(flagged_urls(C::AiSearch::LlmsTxtMissing)).to eq([ "https://example.com/llms.txt" ])

      audit_crawl.update!(site_facts: { "ai_bots_blocked" => [], "llms_txt" => { "present" => true } })
      expect(findings_for(C::AiSearch::BotsBlocked)).to be_empty
      expect(findings_for(C::AiSearch::LlmsTxtMissing)).to be_empty
    end
  end
end
