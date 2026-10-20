require "rails_helper"

RSpec.describe Performance::Measure do
  let(:crawl) { audit_crawl }
  let!(:home) { audit_page("/", internal_pagerank: 0.5) }
  let!(:about) { audit_page("/about", internal_pagerank: 0.2) }

  before { clear_test_redis("seo:psi:*") }

  def run = described_class.call(crawl.reload, limiter: NullRateLimiter.new)

  it "measures the sample, storing metrics and per-page failures" do
    Performance.client = PsiHelpers::FakePsiClient.new(
      { "https://example.com/about" => Performance::Client::Error.new("Lighthouse: NO_FCP") }, default: psi_response
    )

    run

    expect(crawl.reload.performance_status).to eq("done")
    expect(home.performance_results.sole).to have_attributes(performance_score: 42, lcp_ms: 5200, field_inp_ms: 620, error: nil)
    expect(about.performance_results.sole).to have_attributes(error: "Lighthouse: NO_FCP", performance_score: nil)
  end

  it "replaces earlier results when the audit is re-run" do
    Performance.client = PsiHelpers::FakePsiClient.new(default: psi_response)
    run
    run

    expect(crawl.performance_results.count).to eq(2)
  end

  it "records that no key is configured and does nothing when disabled" do
    run
    expect(crawl.reload.performance_status).to eq("skipped_no_key")

    Performance.client = PsiHelpers::FakePsiClient.new(default: psi_response)
    crawl.update!(config: crawl.config.merge("run_pagespeed" => false))
    run
    expect(crawl.reload.performance_status).to be_nil
    expect(crawl.performance_results).to be_empty
  end

  it "stops at the daily limit shared across crawls" do
    client = PsiHelpers::FakePsiClient.new(default: psi_response)
    Performance.client = client
    allow(Performance).to receive(:daily_limit).and_return(1)

    run

    expect(crawl.reload.performance_status).to eq("limited")
    expect(client.urls.size).to eq(1)
    expect(crawl.performance_results.count).to eq(1)
  end
end
