require "rails_helper"
require "zip"

RSpec.describe "Reports" do
  let(:crawl) { audit_crawl.tap { _1.update!(status: "completed", audit_status: "done", pages_crawled: 3, health_score: 72.5,
                                              category_scores: { "metadata" => 61.2, "links" => 100.0 }) } }
  let!(:home) { audit_page("/", title: "Inicio — Café & Niño", word_count: 812) }
  let!(:evil) { audit_page("/evil", title: '=HYPERLINK("http://attacker.example","clic")', meta_description: "+SUM(1,2)") }
  let!(:broken) { audit_page("/broken", status_code: 404, title: nil) }

  before do
    Audit::Catalog.sync_definitions!
    Issue.create!(crawl:, check_key: "http.4xx", page: broken, url: broken.url, details: { "status" => 404 }, priority_score: 81.0)
    Issue.create!(crawl:, check_key: "title.too_long", page: home, url: home.url, details: { "length" => 70 }, priority_score: 12.0)
    audit_link(home, broken.url)
    Audit::LinkGraph.build(crawl)
  end

  def xlsx_entries(data)
    entries = {}
    Zip::File.open_buffer(StringIO.new(data)) { |zip| zip.entries.each { entries[_1.name] = _1.get_input_stream.read.force_encoding("UTF-8") } }
    entries
  end

  describe Reports::PagesCsv do
    let(:csv) { described_class.new(crawl).render }

    it "starts with a BOM and headers in the current language, one row per page" do
      expect(csv).to start_with("\uFEFFURL,HTTP status,")
      expect(I18n.with_locale(:es) { described_class.new(crawl).render }).to start_with("\uFEFFURL,Estado HTTP,")
      rows = CSV.parse(csv.delete_prefix("﻿"), headers: true)
      expect(rows.size).to eq(3)
      expect(rows.find { _1["URL"] == "https://example.com/" }.to_h).to include("Title" => "Inicio — Café & Niño", "Words" => "812", "Indexable" => "yes")
    end

    it "neutralises cells that would run as formulas in a spreadsheet" do
      row = CSV.parse(csv.delete_prefix("﻿"), headers: true).find { _1["URL"] == evil.url }

      expect(row["Title"]).to eq(%('=HYPERLINK("http://attacker.example","clic")))
      expect(row["Meta description"]).to eq("'+SUM(1,2)")
    end
  end

  describe Reports::IssuesCsv do
    it "lists findings by priority with the guidance" do
      rows = CSV.parse(described_class.new(crawl).render.delete_prefix("﻿"), headers: true)

      expect(rows.map { _1["Check"] }).to eq(%w[http.4xx title.too_long])
      expect(rows.first.to_h).to include("Priority" => "81.0", "Severity" => "Error", "Category" => "Crawlability",
                                         "Problem" => "Pages returning 4xx errors", "Details" => "status: 404")
    end
  end

  describe Reports::Workbook do
    let(:entries) { xlsx_entries(described_class.new(crawl).render) }

    it "has one sheet per section" do
      names = entries["xl/workbook.xml"].scan(/<sheet [^>]*name="([^"]+)"/).flatten
      expect(names).to eq([ "Summary", "Problems", "Findings", "Pages", "Broken links", "Duplicates", "Structured data", "Performance" ])
    end

    it "stores third-party text as escaped strings, never as formulas" do
      sheets = entries.select { |name, _| name.start_with?("xl/worksheets/") }.values.join
      strings = CGI.unescapeHTML(entries["xl/sharedStrings.xml"])

      expect(sheets).not_to include("<f>")
      expect(strings).to include(%('=HYPERLINK("http://attacker.example","clic")), "'+SUM(1,2)")
      expect(strings).to include("Inicio — Café & Niño", "SEO audit of example.com", "Pages returning 4xx errors")
    end

    it "lists broken internal links" do
      expect(entries["xl/sharedStrings.xml"]).to include("https://example.com/broken", "internal")
    end
  end

  describe Reports::ExecutiveSummary do
    it "renders a PDF with the score, categories and prioritised problems" do
      pdf = described_class.new(crawl).render

      expect(pdf).to start_with("%PDF")
      # Prawn writes each text run as a hex string in Windows-1252.
      text = pdf.scan(/<([0-9a-f]+)> Tj/).map { [ _1.first ].pack("H*").force_encoding("Windows-1252").encode("UTF-8") }.join("\n")
      expect(text).to include("Site health: 72.5 / 100", "Metadata", "What to fix first", "1. Pages returning 4xx errors")
    end

    it "renders in Spanish when that is the active locale" do
      pdf = I18n.with_locale(:es) { described_class.new(crawl).render }
      text = pdf.scan(/<([0-9a-f]+)> Tj/).map { [ _1.first ].pack("H*").force_encoding("Windows-1252").encode("UTF-8") }.join("\n")

      expect(text).to include("Salud del sitio: 72,5 / 100", "Metadatos", "Qué arreglar primero", "1. Páginas con error 4xx")
    end

    it "transliterates common symbols" do
      pdf = described_class.new(crawl)
      expect(pdf.send(:text, "H1 → H2 ≥ 3 −1 例")).to eq("H1 -> H2 >= 3 -1 ?")
    end

    it "replaces characters outside Windows-1252 instead of failing" do
      crawl.domain.update_columns(host: "例え.jp")
      expect { described_class.new(crawl).render }.not_to raise_error
    end
  end

  it "generates 10 000 pages to CSV and Excel within a minute", :slow do
    crawl_urls = Array.new(10_000) { |i| { crawl_id: crawl.id, url: "https://example.com/p#{i}", url_hash: CrawlUrl.hash_url("p#{i}"), source: "link", state: "done" } }
    ids = CrawlUrl.insert_all(crawl_urls, returning: :id).rows.flatten
    Page.insert_all(ids.each_with_index.map do |id, i|
      { crawl_id: crawl.id, crawl_url_id: id, url: "https://example.com/p#{i}", status_code: 200, title: "Page #{i}", fetched_at: Time.current }
    end)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    Reports::PagesCsv.new(crawl).render
    Reports::Workbook.new(crawl).render

    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 60
  end
end
