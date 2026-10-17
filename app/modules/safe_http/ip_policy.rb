require "ipaddr"

# Addresses the platform must never connect to: loopback, private, link-local (cloud metadata),
# CGNAT, documentation, multicast and reserved ranges. IPv6 forms that embed an IPv4 address
# (mapped, compatible, NAT64, 6to4) are judged by the embedded IPv4 address.
module SafeHttp
  module IpPolicy
    BLOCKED_V4 = %w[
      0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
      192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 192.168.0.0/16 198.18.0.0/15
      198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4 255.255.255.255/32
    ].map { IPAddr.new(_1) }.freeze

    BLOCKED_V6 = %w[
      ::/128 ::1/128 100::/64 2001::/32 2001:db8::/32 64:ff9b:1::/48
      fc00::/7 fe80::/10 fec0::/10 ff00::/8
    ].map { IPAddr.new(_1) }.freeze

    NAT64 = IPAddr.new("64:ff9b::/96")
    SIX_TO_FOUR = IPAddr.new("2002::/16")
    V4_COMPATIBLE = IPAddr.new("::/96")

    module_function

    def blocked?(ip)
      ip = IPAddr.new(ip.to_s) unless ip.is_a?(IPAddr)
      return false if SafeHttp.config.test_allowed_ips.any? { _1.include?(ip) } && Rails.env.test?

      ip.ipv4? ? blocked_v4?(ip) : blocked_v6?(ip)
    end

    def blocked_v4?(ip)
      BLOCKED_V4.any? { _1.include?(ip) }
    end

    def blocked_v6?(ip)
      embedded = embedded_ipv4(ip)
      return blocked_v4?(embedded) if embedded

      BLOCKED_V6.any? { _1.include?(ip) }
    end

    def embedded_ipv4(ip)
      value = ip.to_i
      if ip.ipv4_mapped? || NAT64.include?(ip) || (V4_COMPATIBLE.include?(ip) && value > 1)
        IPAddr.new(value & 0xffff_ffff, Socket::AF_INET)
      elsif SIX_TO_FOUR.include?(ip)
        IPAddr.new((value >> 80) & 0xffff_ffff, Socket::AF_INET)
      end
    end
  end
end
