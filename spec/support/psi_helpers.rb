# Hand-written PSI v5 responses with the fields the parser reads (not real API output).
module PsiHelpers
  def psi_response(score: 0.42, lcp: 5200.4, cls: 0.31, tbt: 640, field: :url, lighthouse: 12)
    audits = {
      "largest-contentful-paint" => { "numericValue" => lcp }, "cumulative-layout-shift" => { "numericValue" => cls },
      "total-blocking-time" => { "numericValue" => tbt }, "first-contentful-paint" => { "numericValue" => 1800 },
      "speed-index" => { "numericValue" => 4100 }, "server-response-time" => { "numericValue" => 320 }
    }
    if lighthouse >= 12
      audits["render-blocking-insight"] = { "title" => "Solicitudes que bloquean el renderizado", "score" => 0, "metricSavings" => { "LCP" => 900, "FCP" => 700 } }
      audits["image-delivery-insight"] = { "title" => "Mejora la entrega de imágenes", "score" => 0.5, "metricSavings" => { "LCP" => 1500 } }
      audits["tiny-insight"] = { "title" => "Ahorro mínimo", "score" => 0, "metricSavings" => { "LCP" => 40 } }
    else
      audits["unused-javascript"] = { "title" => "Reduce el JavaScript sin usar", "score" => 0.3, "details" => { "type" => "opportunity", "overallSavingsMs" => 1200 } }
    end
    body = { "lighthouseResult" => { "categories" => { "performance" => { "score" => score } }, "audits" => audits } }
    if field
      body["loadingExperience"] = {
        "id" => "https://example.com/", "origin_fallback" => field == :origin, "overall_category" => "SLOW",
        "metrics" => {
          "LARGEST_CONTENTFUL_PAINT_MS" => { "percentile" => 4600 }, "CUMULATIVE_LAYOUT_SHIFT_SCORE" => { "percentile" => 12 },
          "INTERACTION_TO_NEXT_PAINT" => { "percentile" => 620 }
        }
      }
    end
    body
  end

  # Stands in for Performance::Client: url → body or exception.
  class FakePsiClient
    attr_reader :urls

    def initialize(responses = {}, default: nil)
      @responses = responses
      @default = default
      @urls = Queue.new
    end

    def run(url, strategy: "mobile")
      @urls << url
      response = @responses.fetch(url) { @default }
      raise response if response.is_a?(Exception)

      response
    end
  end
end

RSpec.configure do |config|
  config.include PsiHelpers
  config.after { Performance.client = nil }
end
