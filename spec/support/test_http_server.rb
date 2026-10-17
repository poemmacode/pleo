require "socket"

# Minimal HTTP/1.1 server on 127.0.0.1 for exercising SafeHttp over real sockets.
# Routes map a path to [status, headers, body] or to a lambda receiving the request hash.
class TestHttpServer
  attr_reader :port, :requests

  def initialize(routes = {})
    @routes = routes
    @requests = Queue.new
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @thread = Thread.new { serve }
  end

  def route(path, response = nil, &block)
    @routes[path] = block || response
  end

  def received
    list = []
    list << @requests.pop until @requests.empty?
    list
  end

  def stop
    @thread.kill
    @server.close
  end

  private
    def serve
      loop do
        client = @server.accept
        Thread.new(client) { handle(_1) }
      end
    rescue IOError
      nil
    end

    def handle(client)
      request_line = client.gets.to_s
      method, path, = request_line.split(" ")
      headers = {}
      while (line = client.gets) && line != "\r\n"
        name, value = line.split(":", 2)
        headers[name.downcase] = value.to_s.strip
      end
      request = { method:, path:, headers:, at: Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      @requests << request

      handler = @routes[path] || [ 404, {}, "not found" ]
      status, response_headers, body = handler.respond_to?(:call) ? handler.call(request) : handler
      write(client, method, status, response_headers, body)
    rescue Errno::EPIPE, Errno::ECONNRESET, IOError
      nil
    ensure
      client.close rescue nil
    end

    def write(client, method, status, headers, body)
      if body.is_a?(Enumerator)
        client.write("HTTP/1.1 #{status} X\r\n#{format_headers(headers)}Connection: close\r\n\r\n")
        body.each { client.write(_1) }
      else
        body = body.to_s
        client.write("HTTP/1.1 #{status} X\r\n#{format_headers(headers)}Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n")
        client.write(body) unless method == "HEAD"
      end
    end

    def format_headers(headers)
      headers.map { |name, value| "#{name}: #{value}\r\n" }.join
    end
end

# Resolver double: maps hostnames to IP lists; a list of lists returns successive answers per lookup.
class StubResolver
  attr_reader :lookups

  def initialize(map)
    @map = map
    @lookups = Hash.new(0)
  end

  def addresses(host)
    answers = @map.fetch(host) { raise SafeHttp::Errors::Resolution, "no such host #{host}" }
    answer = answers.first.is_a?(Array) ? answers[[ @lookups[host], answers.size - 1 ].min] : answers
    @lookups[host] += 1
    answer.map { IPAddr.new(_1) }
  end
end

RSpec.configure do |config|
  config.after { SafeHttp.reset_config! }
end

# Rate-limiter specs use Redis db 15 and remove only their own keys.
module RedisTestHelpers
  def test_redis
    @test_redis ||= RedisClient.config(url: ENV.fetch("TEST_REDIS_URL", "redis://127.0.0.1:6379/15")).new_pool(size: 20)
  end

  def clear_test_redis(pattern = "seo:*")
    keys = test_redis.call("KEYS", pattern)
    test_redis.call("DEL", *keys) if keys.any?
  end
end

RSpec.configure do |config|
  config.include RedisTestHelpers
  # Keep app-side Redis use (broadcast throttling) off the development database.
  config.before(:suite) { SafeHttp.redis = RedisClient.config(url: ENV.fetch("TEST_REDIS_URL", "redis://127.0.0.1:6379/15")).new_pool(size: 10) }
end
