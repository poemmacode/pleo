require "rails_helper"

RSpec.describe Audit::Scoring do
  let(:crawl) { audit_crawl }

  def issue(key, page: nil, url: page&.url)
    Issue.create!(crawl:, check_key: key, page:, url:)
  end

  it "weights every catalog category and sums to 100" do
    categories = Audit::Catalog.definitions.map { _1[:category] }.uniq
    expect(described_class::CATEGORY_WEIGHTS.keys).to match_array(categories)
    expect(described_class::CATEGORY_WEIGHTS.values.sum).to eq(100)
    categories.each { expect(I18n.exists?("audit.categories.#{_1}", :en) && I18n.exists?("audit.categories.#{_1}", :es)).to be(true), _1 }
  end

  it "scores a site without issues at 100" do
    audit_page("/")
    described_class.call(crawl)

    expect(crawl.health_score).to eq(100)
    expect(crawl.category_scores.values.uniq).to eq([ 100.0 ])
  end

  it "scores a site where every check fails on every page at 0" do
    page = audit_page("/")
    Audit::Catalog::CHECKS.each { issue(_1.key, page:) }
    described_class.call(crawl)

    expect(crawl.health_score).to eq(0)
  end

  it "penalises by the square root of coverage within the category" do
    pages = Array.new(4) { audit_page("/p#{_1}") }
    issue("title.missing", page: pages.first) # weight 8, 1 of 4 pages → √0.25 = 0.5
    described_class.call(crawl)

    metadata = Audit::Catalog.definitions.select { _1[:category] == "metadata" }
    total = metadata.sum { _1[:weight] * described_class::SEVERITY_FACTORS[_1[:severity]] }
    expect(crawl.category_scores["metadata"]).to eq((100 * (1 - 8 * 0.5 / total)).round(1))
    expect(crawl.health_score).to eq((100 - (100 - crawl.category_scores["metadata"]) * 14 / 100.0).round(1))
  end

  it "counts site-wide findings as full coverage and notices at a quarter of their weight" do
    Array.new(10) { audit_page("/p#{_1}") }
    issue("sitemap.missing")
    issue("ai.llms_txt_missing", url: "https://example.com/llms.txt")
    described_class.call(crawl)

    crawlability = Audit::Catalog.definitions.select { _1[:category] == "crawlability" }
    total = crawlability.sum { _1[:weight] * described_class::SEVERITY_FACTORS[_1[:severity]] }
    expect(crawl.category_scores["crawlability"]).to eq((100 * (1 - 3.0 / total)).round(1))
    ai_total = 3 + 1 * 0.25
    expect(crawl.category_scores["ai_search"]).to eq((100 * (1 - 0.25 / ai_total)).round(1))
  end

  it "measures coverage of PageSpeed checks against the measured sample" do
    pages = Array.new(10) { audit_page("/p#{_1}") }
    pages.first(2).each { PerformanceResult.create!(crawl:, page: _1, fetched_at: Time.current, lcp_ms: 5000) }
    issue("perf.lcp_poor", page: pages.first)
    described_class.call(crawl)

    performance = Audit::Catalog.definitions.select { _1[:category] == "performance" }
    total = performance.sum { _1[:weight] * described_class::SEVERITY_FACTORS[_1[:severity]] }
    # 1 of 2 measured pages (not 1 of 10 crawled) → √0.5
    expect(crawl.category_scores["performance"]).to eq((100 * (1 - 5 * Math.sqrt(0.5) / total)).round(1))
  end

  it "ranks findings on important pages above the same finding on minor pages" do
    home = audit_page("/", internal_pagerank: 0.5)
    minor = audit_page("/minor", internal_pagerank: 0.05)
    other = Array.new(2) { audit_page("/x#{_1}", internal_pagerank: 0.1) }
    issue("h1.missing", page: home)
    issue("h1.missing", page: minor)
    issue("sitemap.missing")
    described_class.call(crawl)

    # weight 4, coverage 2/4 → 10 × 4 × (0.25 + 0.5 × importance)
    expect(Issue.find_by(page: home).priority_score).to eq(30.0)
    expect(Issue.find_by(page: minor).priority_score).to eq(12.0)
    # site-wide: weight 3, coverage 1, importance 1 → 30
    expect(Issue.find_by(check_key: "sitemap.missing").priority_score).to eq(30.0)
    expect(other).to all(be_present)
  end

  it "falls back to inlinks for pages outside the PageRank graph" do
    audit_page("/", internal_pagerank: 0.4, inlinks_count: 10)
    broken = audit_page("/broken", status_code: 404, internal_pagerank: nil, inlinks_count: 5)
    issue("http.4xx", page: broken)
    described_class.call(crawl)

    # weight 9, coverage 1/2, importance 5/10 → 10 × 9 × (0.25 + 0.25)
    expect(Issue.find_by(page: broken).priority_score).to eq(45.0)
  end
end
