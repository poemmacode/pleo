# Hostnames the platform must never contact or accept as a project domain.
# Épica A extends this module with the IP block list used at connection time.
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

    def blocked_hostname?(host)
      host = host.to_s.downcase.delete_suffix(".")
      BLOCKED_HOSTNAMES.include?(host) ||
        !host.include?(".") ||
        BLOCKED_SUFFIXES.any? { |suffix| host.end_with?(suffix) }
    end
  end
end
