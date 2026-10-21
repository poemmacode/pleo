class User < ApplicationRecord
  MIN_PASSWORD_LENGTH = 12
  ROLES = %w[admin member].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :api_tokens, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: MIN_PASSWORD_LENGTH }, allow_nil: true
  validates :locale, inclusion: { in: -> { I18n.available_locales.map(&:to_s) } }
  validates :role, inclusion: { in: ROLES }

  # Only the ADMIN_EMAIL user is an admin; users:ensure promotes it and demotes everyone else (ADR 0011).
  def admin? = role == "admin"

  # Members see their own projects; the admin sees every project.
  def accessible_projects
    admin? ? Project.all : projects
  end

  # Members may edit their own records but not delete anything critical. The only deletion they keep
  # is removing a domain added by mistake: unverified and never crawled.
  def can_destroy?(record)
    return true if admin?

    case record
    when Domain then record.project.user_id == id && !record.verified? && !record.crawls.exists?
    when ApiToken then record.user_id == id
    else false
    end
  end
end
