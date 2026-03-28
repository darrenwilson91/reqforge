FactoryBot.define do
  factory :change_set_change do
    change_set
    requirement
    change_type { :modified }
    before_snapshot { {} }
    after_snapshot { {} }

    trait :created do
      change_type { :created }
      before_snapshot { {} }
      after_snapshot do
        {
          "uid" => requirement&.uid || "PRJ-0001",
          "title" => requirement&.title || "New Requirement",
          "body" => requirement&.body || "New requirement body",
          "requirement_type" => "functional",
          "status" => "draft",
          "priority" => "must_have",
          "asil_level" => "qm"
        }
      end
    end

    trait :modified do
      change_type { :modified }
    end

    trait :deleted do
      change_type { :deleted }
      after_snapshot { {} }
    end

    trait :with_snapshots do
      before_snapshot do
        {
          "uid" => requirement&.uid || "PRJ-0001",
          "title" => "Original Title",
          "body" => "Original body",
          "requirement_type" => "functional",
          "status" => "draft",
          "priority" => "must_have",
          "asil_level" => "qm",
          "custom_attributes" => {},
          "module_name" => "Test Module",
          "section_name" => "Test Section"
        }
      end
      after_snapshot do
        {
          "uid" => requirement&.uid || "PRJ-0001",
          "title" => "Updated Title",
          "body" => "Updated body",
          "requirement_type" => "functional",
          "status" => "in_review",
          "priority" => "must_have",
          "asil_level" => "asil_b",
          "custom_attributes" => {},
          "module_name" => "Test Module",
          "section_name" => "Test Section"
        }
      end
    end
  end
end
