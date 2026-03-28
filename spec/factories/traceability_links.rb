FactoryBot.define do
  factory :traceability_link do
    association :source_requirement, factory: :requirement
    association :target_requirement, factory: :requirement
    association :created_by, factory: :user
    link_type { :derives_from }
    ai_suggested { false }
    confidence { nil }

    trait :satisfies do
      link_type { :satisfies }
    end

    trait :verifies do
      link_type { :verifies }
    end

    trait :conflicts_with do
      link_type { :conflicts_with }
    end

    trait :refines do
      link_type { :refines }
    end

    trait :implements do
      link_type { :implements }
    end

    trait :parent_child do
      link_type { :parent_child }
    end

    trait :ai_suggested do
      ai_suggested { true }
      confidence { 0.85 }
    end
  end
end
