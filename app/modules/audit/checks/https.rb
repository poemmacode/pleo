module Audit
  module Checks
    module Https
      class NotUsed < PageCheck
        define key: "https.not_used", category: "https", severity: "error", weight: 8

        def evaluate(page) = page.url.start_with?("http://")
      end

      class MixedContent < PageCheck
        define key: "https.mixed_content", category: "https", severity: "warning", weight: 5

        def evaluate(page) = page.mixed_content_count.to_i.positive? && { count: page.mixed_content_count, samples: page.mixed_content_samples }
      end

      class HttpLinks < Links::LinkQueryCheck
        define key: "https.http_links", category: "https", severity: "notice", weight: 2

        def query = grouped("links.internal AND links.to_url LIKE 'http://%' AND pages.url LIKE 'https://%'")
      end

      class CertInvalid < PageCheck
        define key: "https.cert_invalid", category: "https", severity: "error", weight: 9

        def applies?(page) = page.fetch_error.present?
        def evaluate(page) = page.fetch_error.start_with?("Tls") && { error: page.fetch_error }
      end
    end
  end
end
