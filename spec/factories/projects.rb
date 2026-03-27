FactoryBot.define do
  factory :project do
    organization
    sequence(:name) { |n| "Project #{n}" }
    sequence(:prefix) { |n| "PRJ#{n}" }
    status { :active }
    description { Faker::Lorem.paragraph }
    attribute_schema { {} }

    trait :archived do
      status { :archived }
    end

    trait :template do
      status { :template }
    end

    trait :with_custom_attributes do
      attribute_schema do
        {
          "attributes" => [
            { "name" => "Safety Classification", "type" => "select", "options" => %w[QM ASIL-A ASIL-B ASIL-C ASIL-D], "required" => true },
            { "name" => "Verification Method", "type" => "select", "options" => %w[Test Analysis Inspection Demonstration], "required" => false }
          ]
        }
      end
    end
  end
end
