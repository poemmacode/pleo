require "rails_helper"

RSpec.describe Crawling::ProgressBroadcaster do
  let(:crawl) { audit_crawl.tap { _1.update!(status: "running") } }
  let(:stream) { "#{crawl.to_gid_param}:progress" }
  let(:pubsub) { ActionCable.server.pubsub }

  # Each broadcast is a <turbo-stream> element serialized as a JSON string by the test adapter.
  def sent = pubsub.broadcasts(stream).map { Nokogiri::HTML.fragment(JSON.parse(_1)).at_css("turbo-stream") }

  before do
    clear_test_redis("seo:broadcast:*")
    pubsub.clear
  end

  it "sends at most one throttled broadcast per crawl and window" do
    described_class.call(crawl)
    described_class.call(crawl)

    expect(sent.size).to eq(1)
  end

  it "always broadcasts progress and audit when forced" do
    described_class.call(crawl)
    pubsub.clear

    described_class.call(crawl, force: true)

    expect(sent.map { [ _1["action"], _1["target"] ] })
      .to eq([ [ "replace", "progress_crawl_#{crawl.id}" ], [ "replace", "audit_crawl_#{crawl.id}" ] ])
  end

  it "renders the current counters and controls without a request" do
    crawl.update!(pages_crawled: 7)

    described_class.call(crawl, force: true)

    expect(sent.first.to_html).to include("<dd>7</dd>", "Rastreando", "Pausar")
  end
end
