module SafeHttp
  module Robots
    # Path matching per RFC 9309 §2.2.2–2.2.3: `*` matches any sequence, a trailing `$` anchors the end,
    # comparisons are on percent-encoded octets with case-insensitive hex digits.
    module Matcher
      module_function

      def normalize(value)
        value.b.gsub(/[^\x21-\x7e]/n) { |byte| format("%%%02X", byte.ord) }
             .gsub(/%[0-9a-f]{2}/i, &:upcase)
             .force_encoding(Encoding::US_ASCII)
      end

      def matches?(pattern, path)
        compile(pattern).match?(path)
      end

      def compile(pattern)
        anchored = pattern.end_with?("$")
        body = anchored ? pattern.delete_suffix("$") : pattern
        source = body.split("*", -1).map { Regexp.escape(_1) }.join(".*")
        Regexp.new("\\A#{source}#{anchored ? "\\z" : ""}")
      end

      # Path plus query of a URL, normalized like the patterns.
      def path_for(url)
        uri = url.is_a?(URI) ? url : URI.parse(url.to_s)
        path = uri.path.to_s.empty? ? "/" : uri.path
        path += "?#{uri.query}" if uri.query
        normalize(path)
      end
    end
  end
end
