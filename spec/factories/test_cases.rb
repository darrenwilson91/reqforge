FactoryBot.define do
  factory :test_case do
    project
    requirement { association :requirement, project: project }
    created_by { association :user }
    title { Faker::Lorem.sentence(word_count: 4) }
    description { Faker::Lorem.paragraph }
    preconditions { "System is in normal operating mode" }
    steps { "1. Perform action\n2. Observe result" }
    expected_result { "System responds correctly" }
    test_type { :unit }
    status { :not_run }
    priority { :must_have }
    uid { nil } # auto-generated

    trait :integration do
      test_type { :integration }
    end

    trait :system do
      test_type { :system }
    end

    trait :acceptance do
      test_type { :acceptance }
    end

    trait :safety do
      test_type { :safety }
      priority { :must_have }
    end

    trait :draft do
      status { :draft }
    end

    trait :ready do
      status { :ready }
    end

    trait :passed do
      status { :passed }
    end

    trait :failed do
      status { :failed }
    end

    trait :blocked do
      status { :blocked }
    end

    trait :without_requirement do
      requirement { nil }
    end
  end
end
