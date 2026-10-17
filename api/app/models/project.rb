class Project < ApplicationRecord
  belongs_to :user
  has_many :domains, dependent: :destroy

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 120 }
  validates :monthly_api_budget_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
