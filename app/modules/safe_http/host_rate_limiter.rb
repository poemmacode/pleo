module SafeHttp
  # Spaces requests to each host across all workers and processes (docs/03 §2, A.3).
  #
  # Uses GCRA with a burst of one: Redis stores, per host, the earliest time the next request may
  # start. The check-and-advance is a single Lua script using Redis' clock, so it is atomic and
  # independent of worker clocks. A denied caller receives how long to wait and is expected to
  # re-enqueue (jobs) or sleep (#acquire).
  class HostRateLimiter
    MAX_RPS = 10.0
    KEY_PREFIX = "seo:rate:host:".freeze

    RESERVE = <<~LUA.freeze
      local interval = tonumber(ARGV[1])
      local t = redis.call('TIME')
      local now = tonumber(t[1]) * 1000 + math.floor(tonumber(t[2]) / 1000)
      local next_at = tonumber(redis.call('GET', KEYS[1]) or '0')
      if next_at > now then
        return next_at - now
      end
      redis.call('SET', KEYS[1], now + interval, 'PX', interval + 60000)
      return 0
    LUA

    PENALIZE = <<~LUA.freeze
      local delay = tonumber(ARGV[1])
      local t = redis.call('TIME')
      local now = tonumber(t[1]) * 1000 + math.floor(tonumber(t[2]) / 1000)
      local next_at = math.max(tonumber(redis.call('GET', KEYS[1]) or '0'), now + delay)
      redis.call('SET', KEYS[1], next_at, 'PX', next_at - now + 60000)
      return next_at - now
    LUA

    def initialize(redis: SafeHttp.redis)
      @redis = redis
    end

    # Returns 0.0 if the caller may send a request now, otherwise the seconds to wait.
    def reserve(host, rps:)
      raise ArgumentError, "rps must be between 0 and #{MAX_RPS}" unless rps.positive? && rps <= MAX_RPS

      interval_ms = (1000.0 / rps).ceil
      @redis.call("EVAL", RESERVE, 1, key(host), interval_ms) / 1000.0
    end

    # Blocks until a slot is granted. For one-off fetches (robots.txt, sitemaps); crawl jobs use #reserve.
    def acquire(host, rps:, max_wait: 30)
      waited = 0.0
      loop do
        wait = reserve(host, rps:)
        return waited if wait.zero?
        raise Errors::Timeout, "waiting for a slot on #{host} exceeded #{max_wait}s" if waited + wait > max_wait

        sleep(wait)
        waited += wait
      end
    end

    # Pushes the host's next slot at least `seconds` into the future (Retry-After, 429/503).
    def penalize(host, seconds)
      @redis.call("EVAL", PENALIZE, 1, key(host), (seconds * 1000).ceil) / 1000.0
    end

    private
      def key(host)
        "#{KEY_PREFIX}#{host.to_s.downcase}"
      end
  end
end
