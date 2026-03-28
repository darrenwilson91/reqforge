FactoryBot.define do
  factory :membership do
    user
    organization
    role { :admin }

    trait :project_manager do
      role { :project_manager }
    end

    trait :author do
      role { :author }
    end

    trait :reviewer do
      role { :reviewer }
    end

    trait :viewer do
      role { :viewer }
    end
  end
end
