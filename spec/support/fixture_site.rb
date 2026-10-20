# A small website served by TestHttpServer, used by crawl integration specs.
# The expected crawl results are listed next to each route.
module FixtureSite
  HOST = "site.example.com".freeze

  module_function

  def build(server)
    origin = "http://#{HOST}:#{server.port}"
    html = ->(body) { [ 200, { "Content-Type" => "text/html; charset=utf-8" }, "<!doctype html><html><head><title>t</title></head><body>#{body}</body></html>" ] }

    server.route("/robots.txt", [ 200, { "Content-Type" => "text/plain" }, <<~TXT ])
      User-agent: *
      Disallow: /private/
      Sitemap: #{origin}/sitemap_index.xml
    TXT
    server.route("/sitemap_index.xml", [ 200, { "Content-Type" => "application/xml" }, <<~XML ])
      <?xml version="1.0" encoding="UTF-8"?>
      <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <sitemap><loc>#{origin}/sitemap-pages.xml.gz</loc></sitemap>
      </sitemapindex>
    XML
    server.route("/sitemap-pages.xml.gz", [ 200, { "Content-Type" => "application/gzip" }, ActiveSupport::Gzip.compress(<<~XML) ])
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <url><loc>#{origin}/</loc></url>
        <url><loc>#{origin}/about</loc></url>
        <url><loc>#{origin}/orphan</loc></url>
        <url><loc>http://other.example.org/x</loc></url>
      </urlset>
    XML
    server.route("/sitemap.xml", [ 404, {}, "" ])

    server.route("/", html.call(<<~HTML))
      <a href="/about">About us</a>
      <a href="/about#team">Team</a>
      <a href="blog/">Blog</a>
      <a href="/private/secret">Private</a>
      <a href="/old">Old</a>
      <a href="/missing">Broken</a>
      <a href="https://external.example.net/">External</a>
      <a href="mailto:hello@site.example.com">Email</a>
      <a href="/deep/1">Deep</a>
    HTML
    server.route("/about", html.call('<a href="/">Home</a>'))
    server.route("/blog/", html.call('<a href="post-1" rel="nofollow">Post</a> <a href="/blog/page?utm_source=x">Page</a>'))
    server.route("/blog/post-1", html.call("post"))
    server.route("/blog/page", html.call("page"))
    server.route("/old", [ 301, { "Location" => "/about" }, "" ])
    server.route("/missing", [ 404, { "Content-Type" => "text/html" }, "no" ])
    server.route("/orphan", html.call("only in the sitemap"))
    server.route("/private/secret", html.call("must never be requested"))
    (1..5).each { |n| server.route("/deep/#{n}", html.call(%(<a href="/deep/#{n + 1}">next</a>))) }
    origin
  end
end

# Grants every rate-limit request immediately so integration specs run fast.
class NullRateLimiter
  def reserve(*, **) = 0.0
  def acquire(*, **) = 0.0
  def penalize(*) = 0.0
end
