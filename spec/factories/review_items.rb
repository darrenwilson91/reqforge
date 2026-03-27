FactoryBot.define do
  factory :review_item do
    review
    requirement { association :requirement, project: review.project }
    status { :pending }
    snapshot { {} }

    trait :approved do
      status { :approved }
    end

    trait :rejected do
      status { :rejected }
    end

    trait :needs_changes do
      status { :needs_changes }
    end

    trait :with_snapshot do
      after(:create) do |review_item|
        review_item.snapshot_requirement!
      end
    end
  end
end
