module SafeHttp
  # Parses a Retry-After header (delta-seconds or HTTP-date) into seconds, capped.
  module RetryAfter
    MAX_SECONDS = 3600

    module_function

    def parse(value, now: Time.current)
      value = value.to_s.strip
      return if value.empty?

      seconds = if value.match?(/\A\d+\z/)
        value.to_i
      else
        (Time.httpdate(value) - now).ceil
      end
      seconds.clamp(0, MAX_SECONDS)
    rescue ArgumentError
      nil
    end
  end
end
