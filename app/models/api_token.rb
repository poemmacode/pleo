# Bearer token for the JSON API. Only the SHA-256 digest is stored; the token is shown once on creation.
class ApiToken < ApplicationRecord
  PREFIX = "seop_".freeze
  # Writing last_used_at on every request would turn reads into writes.
  TOUCH_INTERVAL = 5.minutes

  belongs_to :user

  attr_reader :token

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 80 }

  before_validation :generate_token, on: :create

  def self.digest(token) = OpenSSL::Digest::SHA256.hexdigest(token.to_s)

  def self.authenticate(token)
    return if token.blank? || !token.start_with?(PREFIX)

    find_by(token_digest: digest(token))&.tap(&:touch_usage)
  end

  def touch_usage
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < TOUCH_INTERVAL.ago
  end

  private
    def generate_token
      @token = "#{PREFIX}#{SecureRandom.base58(40)}"
      self.token_digest = self.class.digest(@token)
      self.token_prefix = @token.first(PREFIX.length + 6)
    end
end
