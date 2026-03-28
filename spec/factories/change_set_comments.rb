FactoryBot.define do
  factory :change_set_comment do
    association :change_set
    change_set_change { nil }
    association :user
    body { Faker::Lorem.paragraph }
    parent_comment { nil }
    resolved { false }
    resolved_by { nil }
    resolved_at { nil }

    trait :inline do
      association :change_set_change
    end

    trait :conversation do
      change_set_change { nil }
    end

    trait :resolved do
      resolved { true }
      association :resolved_by, factory: :user
      resolved_at { Time.current }
    end

    trait :reply do
      parent_comment { association :change_set_comment, change_set: instance.change_set }
    end
  end
end
