FactoryBot.define do
  factory :change_set do
    project
    association :created_by, factory: :user
    sequence(:title) { |n| "Change Set #{n}" }
    description { "Description of changes" }
    status { :draft }

    trait :open do
      status { :open }
    end

    trait :in_review do
      status { :in_review }
    end

    trait :approved do
      status { :approved }
    end

    trait :merged do
      status { :merged }
      association :merged_by, factory: :user
      merged_at { Time.current }
      merge_commit_message { "Merged change set" }
    end

    trait :closed do
      status { :closed }
    end

    trait :with_baseline do
      association :source_baseline, factory: :review
    end
  end
end
