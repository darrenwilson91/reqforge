FactoryBot.define do
  factory :ai_analysis_result do
    requirement
    analysis_type { "quality_analysis" }
    status { :pending }
    result_data { {} }
    error_message { nil }
    completed_at { nil }

    trait :quality_analysis do
      analysis_type { "quality_analysis" }
    end

    trait :link_suggestion do
      analysis_type { "link_suggestion" }
    end

    trait :impact_analysis do
      analysis_type { "impact_analysis" }
    end

    trait :running do
      status { :running }
    end

    trait :completed do
      status { :completed }
      completed_at { Time.current }
      error_message { nil }
    end

    trait :failed do
      status { :failed }
      completed_at { Time.current }
      error_message { "Analysis service unavailable" }
    end

    trait :with_quality_result do
      analysis_type { "quality_analysis" }
      status { :completed }
      completed_at { Time.current }
      result_data do
        {
          "overall_score" => 75,
          "checks" => [
            { "rule" => "ambiguity", "score" => 80, "passed" => true, "details" => "No vague terms found" },
            { "rule" => "completeness", "score" => 60, "passed" => false, "details" => "Missing acceptance criteria" },
            { "rule" => "singularity", "score" => 90, "passed" => true, "details" => "Single requirement per statement" }
          ],
          "suggestions" => ["Add measurable acceptance criteria", "Specify response time thresholds"],
          "summary" => "Good quality with minor completeness issues"
        }
      end
    end

    trait :with_link_suggestions do
      analysis_type { "link_suggestion" }
      status { :completed }
      completed_at { Time.current }
      result_data do
        {
          "suggestions" => [
            { "target_uid" => "SYS-0002", "link_type" => "derives_from", "confidence" => 0.85, "rationale" => "System requirement derives from stakeholder need" },
            { "target_uid" => "SYS-0003", "link_type" => "satisfies", "confidence" => 0.72, "rationale" => "Satisfies interface specification" }
          ]
        }
      end
    end

    trait :with_impact_result do
      analysis_type { "impact_analysis" }
      status { :completed }
      completed_at { Time.current }
      result_data do
        {
          "impacts" => [
            { "requirement_uid" => "SYS-0005", "severity" => "high", "impact_type" => "direct", "description" => "Directly linked safety requirement affected" }
          ],
          "summary" => "One high-severity direct impact identified",
          "risk_level" => "significant"
        }
      end
    end

    trait :stale do
      status { :completed }
      completed_at { 48.hours.ago }
    end
  end
end
