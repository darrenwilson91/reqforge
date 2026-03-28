FactoryBot.define do
  factory :section do
    requirement_module
    parent_section { nil }
    sequence(:name) { |n| "Section #{n}" }

    trait :nested do
      parent_section { association :section, requirement_module: requirement_module }
    end
  end
end
