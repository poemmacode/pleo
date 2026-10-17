module SafeHttp
  # Self-protection when a site struggles (docs/03 §2, A.4). Immutable state: callers persist it
  # (the crawl row, under a lock) and act on the decision.
  #
  # Within a 60 s window with at least 10 responses, if more than 20 % are 429/5xx/network errors,
  # the rate is halved and the window restarts. The third reduction pauses the crawl.
  class AdaptiveRate < Data.define(:rps, :reductions, :window_started_at, :total, :failures)
    WINDOW_SECONDS = 60
    MIN_SAMPLES = 10
    FAILURE_RATIO = 0.2
    MAX_REDUCTIONS = 3
    MIN_RPS = 0.1

    def self.start(rps, now: Time.current)
      new(rps: rps.to_f, reductions: 0, window_started_at: now.to_f, total: 0, failures: 0)
    end

    def self.from_h(hash)
      new(**hash.symbolize_keys.slice(*members))
    end

    def self.failure?(outcome)
      outcome.is_a?(Integer) ? (outcome == 429 || outcome >= 500) : true
    end

    # outcome: an HTTP status, or :error for timeouts/connection failures.
    # Returns [new_state, decision] where decision is :ok, :slow_down or :pause.
    def record(outcome, now: Time.current)
      state = now.to_f - window_started_at > WINDOW_SECONDS ? with(window_started_at: now.to_f, total: 0, failures: 0) : self
      state = state.with(total: state.total + 1, failures: state.failures + (self.class.failure?(outcome) ? 1 : 0))

      return [ state, :ok ] unless state.total >= MIN_SAMPLES && state.failures > state.total * FAILURE_RATIO

      reduced = state.with(rps: [ state.rps / 2, MIN_RPS ].max, reductions: state.reductions + 1,
                           window_started_at: now.to_f, total: 0, failures: 0)
      [ reduced, reduced.reductions >= MAX_REDUCTIONS ? :pause : :slow_down ]
    end
  end
end
