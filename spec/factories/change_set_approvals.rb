FactoryBot.define do
  factory :change_set_approval do
    change_set
    association :user
    status { :pending }
    body { nil }

    trait :approved do
      status { :approved }
      body { "Looks good, approved." }
    end

    trait :changes_requested do
      status { :changes_requested }
      body { "Please address the issues noted." }
    end

    trait :commented do
      status { :commented }
      body { "Left some comments for consideration." }
    end

    trait :with_body do
      body { "Review feedback on the change set." }
    end
  end
end
