require "rails_helper"

RSpec.describe SafeHttp::HostRateLimiter do
  let(:limiter) { described_class.new(redis: test_redis) }

  before { clear_test_redis }
  after { clear_test_redis }

  it "grants the first request and asks the next one to wait one interval" do
    expect(limiter.reserve("a.example.com", rps: 2)).to eq(0)
    expect(limiter.reserve("a.example.com", rps: 2)).to be_within(0.05).of(0.5)
  end

  it "tracks hosts independently and case-insensitively" do
    expect(limiter.reserve("A.example.com", rps: 1)).to eq(0)
    expect(limiter.reserve("a.example.COM", rps: 1)).to be > 0
    expect(limiter.reserve("b.example.com", rps: 1)).to eq(0)
  end

  it "rejects rates outside the allowed range" do
    expect { limiter.reserve("a.example.com", rps: 0) }.to raise_error(ArgumentError)
    expect { limiter.reserve("a.example.com", rps: 11) }.to raise_error(ArgumentError)
  end

  it "honours Retry-After penalties" do
    limiter.penalize("a.example.com", 3)

    expect(limiter.reserve("a.example.com", rps: 10)).to be_within(0.1).of(3)
  end

  it "keeps 10 concurrent workers at the configured 2 req/s against a real server" do
    server = TestHttpServer.new("/" => [ 200, {}, "ok" ])
    SafeHttp.config.allow_ips_for_tests!([ "127.0.0.1" ])
    SafeHttp.config.allowed_ports = [ server.port ]
    client = SafeHttp::Client.new(resolver: StubResolver.new("site.example.com" => [ "127.0.0.1" ]))
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3.2

    workers = Array.new(10) do
      Thread.new do
        while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
          wait = limiter.reserve("site.example.com", rps: 2)
          next sleep([ wait, 0.05 ].max) if wait.positive?

          client.get("http://site.example.com:#{server.port}/")
        end
      end
    end
    workers.each(&:join)

    times = server.received.map { _1[:at] }.sort
    server.stop
    gaps = times.each_cons(2).map { |a, b| b - a }
    # 3.2 s at 2 req/s → at most 7 requests, each at least ~0.5 s after the previous one.
    expect(times.size).to be_between(6, 7)
    expect(gaps.min).to be >= 0.45
  end
end

RSpec.describe SafeHttp::RetryAfter do
  let(:now) { Time.utc(2026, 10, 17, 12, 0, 0) }

  it "parses seconds and HTTP dates, capping the result" do
    expect(described_class.parse("120", now:)).to eq(120)
    expect(described_class.parse("Sat, 17 Oct 2026 12:00:30 GMT", now:)).to eq(30)
    expect(described_class.parse("999999", now:)).to eq(3600)
    expect(described_class.parse("Sat, 17 Oct 2026 11:00:00 GMT", now:)).to eq(0)
    expect(described_class.parse("soon", now:)).to be_nil
    expect(described_class.parse(nil, now:)).to be_nil
  end
end

RSpec.describe SafeHttp::AdaptiveRate do
  let(:t0) { Time.utc(2026, 10, 17, 12) }

  def feed(state, outcomes, at:)
    decisions = outcomes.map { |outcome| state, decision = state.record(outcome, now: at); decision }
    [ state, decisions ]
  end

  it "keeps the rate while failures stay at or below 20 %" do
    state, decisions = feed(described_class.start(4, now: t0), [ 200 ] * 8 + [ 503, 429 ], at: t0 + 5)

    expect(decisions.uniq).to eq([ :ok ])
    expect(state.rps).to eq(4)
  end

  it "halves the rate when more than 20 % fail within the window" do
    state, decisions = feed(described_class.start(4, now: t0), [ 200 ] * 7 + [ 503, 429, :error ], at: t0 + 5)

    expect(decisions.last).to eq(:slow_down)
    expect(state).to have_attributes(rps: 2.0, reductions: 1, total: 0)
  end

  it "needs at least 10 samples before reacting" do
    _, decisions = feed(described_class.start(4, now: t0), [ 503 ] * 9, at: t0 + 1)

    expect(decisions.uniq).to eq([ :ok ])
  end

  it "forgets failures from an expired window" do
    state, = feed(described_class.start(4, now: t0), [ 503 ] * 5, at: t0 + 1)
    state, decisions = feed(state, [ 200 ] * 10, at: t0 + 70)

    expect(decisions.uniq).to eq([ :ok ])
    expect(state.failures).to eq(0)
  end

  it "pauses on the third reduction" do
    state = described_class.start(8, now: t0)
    decisions = 3.times.map { |i| state, d = feed(state, [ 503 ] * 10, at: t0 + i); d.last }

    expect(decisions).to eq(%i[slow_down slow_down pause])
    expect(state.rps).to eq(1.0)
  end

  it "round-trips through a hash for persistence" do
    state = described_class.start(3, now: t0)

    expect(described_class.from_h(state.to_h.stringify_keys)).to eq(state)
  end
end
