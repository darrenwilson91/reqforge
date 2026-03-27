FactoryBot.define do
  factory :review_participant do
    review
    user
    role { :reviewer }

    trait :author do
      role { :author }
    end

    trait :reviewer do
      role { :reviewer }
    end

    trait :approver do
      role { :approver }
    end

    trait :observer do
      role { :observer }
    end
  end
end
