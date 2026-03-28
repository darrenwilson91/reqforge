FactoryBot.define do
  factory :requirement_module do
    project
    sequence(:name) { |n| "Module #{n}" }
    description { Faker::Lorem.paragraph }
  end
end
