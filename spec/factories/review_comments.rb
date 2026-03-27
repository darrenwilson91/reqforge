FactoryBot.define do
  factory :review_comment do
    review_item
    user
    body { Faker::Lorem.paragraph }

    trait :resolved do
      resolved { true }
      resolved_by { association(:user) }
      resolved_at { Time.current }
    end

    trait :reply do
      parent_comment { association(:review_comment, review_item: review_item) }
    end
  end
end
