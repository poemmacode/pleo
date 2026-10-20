class Domain < ApplicationRecord
  VERIFICATION_METHODS = %w[dns_txt html_file meta gsc].freeze
  TXT_PREFIX = "seo-platform-verify=".freeze

  belongs_to :project
  has_many :crawls, dependent: :destroy

  attribute :host_input, :string
  before_validation :normalize_host, if: -> { host_input.present? }
  before_validation :assign_verification_token, on: :create

  validates :host, presence: true, uniqueness: { scope: :project_id }, unless: -> { @host_error }
  validates :host, length: { maximum: 253 }
  validates :verification_token, presence: true
  validates :verification_method, inclusion: { in: VERIFICATION_METHODS }, allow_nil: true
  validate :host_must_be_normalizable

  def verified?
    verified_at.present?
  end

  def txt_record_value
    "#{TXT_PREFIX}#{verification_token}"
  end

  private
    def normalize_host
      @host_error = nil
      self.host = Domain::HostNormalizer.call(host_input)
    rescue Domain::HostNormalizer::InvalidHost => e
      self.host = nil
      @host_error = e.code
    end

    def host_must_be_normalizable
      errors.add(:host, @host_error) if @host_error
    end

    def assign_verification_token
      self.verification_token ||= SecureRandom.alphanumeric(32)
    end
end
