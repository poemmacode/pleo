FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { RequestHelpers::PASSWORD }

    trait :admin do
      role { "admin" }
    end
  end

  factory :project do
    user
    name { "My site" }
  end

  factory :domain do
    project
    sequence(:host_input) { |n| "site#{n}.com" }
  end
end
