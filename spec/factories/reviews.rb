FactoryBot.define do
  factory :review do
    project
    association :created_by, factory: :user
    sequence(:title) { |n| "Review #{n}" }
    description { Faker::Lorem.paragraph }
    status { :draft }
    baseline_snapshot { {} }

    trait :open do
      status { :open }
    end

    trait :in_progress do
      status { :in_progress }
    end

    trait :completed do
      status { :completed }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :with_snapshot do
      after(:create) do |review|
        review.snapshot_requirements!
      end
    end
  end
end
