require "resolv"

module SafeHttp
  # Resolves A and AAAA records through DNS only (no /etc/hosts), so "localhost"-style
  # overrides on the worker cannot redirect traffic.
  class Resolver
    TIMEOUT_SECONDS = 3

    def addresses(host)
      Resolv::DNS.open do |dns|
        dns.timeouts = TIMEOUT_SECONDS
        records = dns.getresources(host, Resolv::DNS::Resource::IN::A) +
          dns.getresources(host, Resolv::DNS::Resource::IN::AAAA)
        records.map { IPAddr.new(_1.address.to_s) }
      end
    rescue Resolv::ResolvError, Resolv::ResolvTimeout => e
      raise Errors::Resolution, "no se pudo resolver #{host}: #{e.class.name.demodulize}"
    end
  end
end
