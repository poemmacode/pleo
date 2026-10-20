class User < ApplicationRecord
  MIN_PASSWORD_LENGTH = 12

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :projects, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: MIN_PASSWORD_LENGTH }, allow_nil: true
  validates :locale, inclusion: { in: -> { I18n.available_locales.map(&:to_s) } }
end
