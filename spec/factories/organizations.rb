FactoryBot.define do
  factory :organization do
    name { Faker::Company.name }
    sequence(:slug) { |n| "org-#{n}" }
    settings { {} }
  end
end
