require "rails_helper"

RSpec.describe Audit::PageRank do
  it "ranks pages by incoming links and keeps the total at 1" do
    # 1 → 2, 3 → 2, 2 → 1, 4 has no links (dangling)
    ranks = described_class.compute([ 1, 2, 3, 4 ], [ 1, 3, 2 ], [ 2, 2, 1 ])

    expect(ranks.sum).to be_within(1e-9).of(1.0)
    expect(ranks[1]).to be > ranks[0]
    expect(ranks[0]).to be > ranks[2]
    expect(ranks[2]).to be_within(1e-9).of(ranks[3])
  end

  it "ignores edges to unknown nodes" do
    expect(described_class.compute([ 1, 2 ], [ 1, 1 ], [ 2, 99 ]).sum).to be_within(1e-9).of(1.0)
  end

  it "handles 50k pages and 1M links well under a minute", :slow do
    n = 50_000
    sources = Array.new(1_000_000) { rand(1..n) }
    targets = Array.new(1_000_000) { rand(1..n) }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    described_class.compute((1..n).to_a, sources, targets)

    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 60
  end
end

RSpec.describe Audit::NearDuplicates do
  it "groups hashes within 3 bits, transitively, and leaves distinct pages alone" do
    base = 0b1011 << 40
    pages = [ [ 1, base ], [ 2, base ^ 0b111 ], [ 3, base ^ (0b111 << 3) ], [ 4, base ^ ((2**63) - 1) ], [ 5, 12_345 ] ]

    expect(described_class.groups(pages)).to eq([ [ 1, 2, 3 ] ])
  end

  it "finds near duplicates that only share one band" do
    a = 0x1234_5678_9abc_def0
    b = a ^ (1 << 1) ^ (1 << 17) ^ (1 << 33) # differs in three bands, same top band

    expect(described_class.groups([ [ 1, Crawling::Simhash.to_signed(a) ], [ 2, Crawling::Simhash.to_signed(b) ] ])).to eq([ [ 1, 2 ] ])
  end
end
