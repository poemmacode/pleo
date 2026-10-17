module SafeHttp
  module Errors
    class Base < StandardError; end

    # The URL or one of the addresses it resolves to is not allowed (SSRF guard).
    class UnsafeTarget < Base; end
    class InvalidUrl < Base; end
    class Resolution < Base; end
    class Timeout < Base; end
    class Connection < Base; end
    class Tls < Base; end
    class TooManyRedirects < Base; end
  end
end
