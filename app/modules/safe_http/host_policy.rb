# Hostnames the platform must never contact or accept as a project domain.
# Addresses are checked separately by SafeHttp::IpPolicy after resolution.
module SafeHttp
  module HostPolicy
    BLOCKED_HOSTNAMES = %w[
      localhost
      metadata
      metadata.google.internal
      instance-data
      instance-data.ec2.internal
    ].freeze

    BLOCKED_SUFFIXES = %w[
      .localhost
      .local
      .localdomain
      .internal
      .intranet
      .lan
      .home.arpa
      .arpa
      .test
      .example
      .invalid
    ].freeze

    module_function

    # Hosts made only of numeric labels ("2130706433", "0x7f.1", "0177.0.0.1") are IPv4 shorthands
    # that some resolvers and browsers accept; they are never legitimate site names.
    def numeric_host?(host)
      host.to_s.delete_suffix(".").split(".").all? { |label| label.match?(/\A(0x[0-9a-f]*|\d+)\z/i) }
    end

    def blocked_hostname?(host)
      host = host.to_s.downcase.delete_suffix(".")
      BLOCKED_HOSTNAMES.include?(host) ||
        !host.include?(".") ||
        BLOCKED_SUFFIXES.any? { |suffix| host.end_with?(suffix) }
    end
  end
end
