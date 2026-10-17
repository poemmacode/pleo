module CrawlsHelper
  STATUS_LABELS = {
    "queued" => "En cola", "running" => "Rastreando", "paused" => "En pausa",
    "completed" => "Completado", "failed" => "Fallido", "cancelled" => "Cancelado"
  }.freeze
  REASON_LABELS = {
    "user" => "por el usuario",
    "server_overloaded" => "el servidor respondía con errores; se redujo la velocidad y se pausó",
    "max_pages_reached" => "se alcanzó el máximo de páginas",
    "robots_unreachable" => "robots.txt no responde: no se rastrea nada (RFC 9309)"
  }.freeze
  SKIP_LABELS = {
    "robots" => "Bloqueadas por robots.txt", "limit" => "Fuera del límite de páginas",
    "unsafe_host" => "Host no permitido (IP privada)", "error" => "Error repetido", "cancelled" => "Crawl cancelado"
  }.freeze
  ROBOTS_LABELS = {
    "parsed" => "robots.txt leído", "unavailable" => "sin robots.txt (todo permitido)",
    "unreachable" => "robots.txt inaccesible (nada permitido)"
  }.freeze
  PAGE_STATUS_FILTERS = { "" => "Todos", "2xx" => "2xx", "3xx" => "3xx", "4xx" => "4xx", "5xx" => "5xx", "error" => "Sin respuesta" }.freeze

  def crawl_status_label(status) = STATUS_LABELS.fetch(status, status)
  def crawl_reason_label(reason) = REASON_LABELS.fetch(reason, reason)
  def skip_reason_label(reason) = SKIP_LABELS.fetch(reason, reason)
  def robots_outcome_label(outcome) = ROBOTS_LABELS.fetch(outcome, outcome)

  def crawl_finished?(crawl) = Crawl::FINISHED_STATUSES.include?(crawl.status)

  def crawl_percent(crawl)
    return 100 if crawl_finished?(crawl)

    done = crawl.pages_crawled + crawl.pages_failed
    target = [ crawl.crawl_config.max_pages, [ crawl.pages_discovered - crawl.pages_skipped, done, 1 ].max ].min
    [ 99, (done * 100.0 / target).round ].min
  end
end
