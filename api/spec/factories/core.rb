FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { RequestHelpers::PASSWORD }
  end

  factory :project do
    user
    name { "Mi sitio" }
  end

  factory :domain do
    project
    sequence(:host_input) { |n| "sitio#{n}.com" }
  end
end
