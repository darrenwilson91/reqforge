FactoryBot.define do
  factory :change_set_rule do
    association :project
    min_approvals { 1 }
    require_all_conversations_resolved { true }
    auto_merge_on_approval { false }

    trait :strict do
      min_approvals { 2 }
      require_all_conversations_resolved { true }
      auto_merge_on_approval { false }
    end

    trait :relaxed do
      min_approvals { 1 }
      require_all_conversations_resolved { false }
      auto_merge_on_approval { true }
    end

    trait :auto_merge do
      auto_merge_on_approval { true }
    end
  end
end
