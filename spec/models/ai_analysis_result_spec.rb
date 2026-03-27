require "rails_helper"

RSpec.describe AiAnalysisResult, type: :model do
  describe "factory" do
    it "has a valid factory" do
      expect(build(:ai_analysis_result)).to be_valid
    end

    it "has valid trait factories" do
      %i[quality_analysis link_suggestion impact_analysis running completed failed
         with_quality_result with_link_suggestions with_impact_result stale].each do |trait|
        expect(build(:ai_analysis_result, trait)).to be_valid
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:requirement) }
  end

  describe "validations" do
    subject { build(:ai_analysis_result) }

    it { is_expected.to validate_presence_of(:analysis_type) }

    it "validates inclusion of analysis_type" do
      expect(build(:ai_analysis_result, analysis_type: "quality_analysis")).to be_valid
      expect(build(:ai_analysis_result, analysis_type: "link_suggestion")).to be_valid
      expect(build(:ai_analysis_result, analysis_type: "impact_analysis")).to be_valid
      expect(build(:ai_analysis_result, analysis_type: "invalid_type")).not_to be_valid
    end

    it "validates uniqueness of analysis_type scoped to requirement" do
      requirement = create(:requirement)
      create(:ai_analysis_result, requirement: requirement, analysis_type: "quality_analysis")
      duplicate = build(:ai_analysis_result, requirement: requirement, analysis_type: "quality_analysis")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:analysis_type]).to include("already exists for this requirement")
    end

    it "allows same analysis_type for different requirements" do
      req1 = create(:requirement)
      req2 = create(:requirement)
      create(:ai_analysis_result, requirement: req1, analysis_type: "quality_analysis")
      expect(build(:ai_analysis_result, requirement: req2, analysis_type: "quality_analysis")).to be_valid
    end

    it "allows different analysis_types for the same requirement" do
      requirement = create(:requirement)
      create(:ai_analysis_result, requirement: requirement, analysis_type: "quality_analysis")
      expect(build(:ai_analysis_result, requirement: requirement, analysis_type: "link_suggestion")).to be_valid
    end
  end

  describe "enum" do
    it "defines status enum" do
      expect(described_class.statuses).to eq(
        "pending" => 0, "running" => 1, "completed" => 2, "failed" => 3
      )
    end
  end

  describe "defaults" do
    it "defaults status to pending" do
      result = described_class.new
      expect(result.status).to eq("pending")
    end

    it "defaults result_data to empty hash" do
      result = described_class.new
      expect(result.result_data).to eq({})
    end
  end

  describe "constants" do
    it "defines valid analysis types" do
      expect(AiAnalysisResult::ANALYSIS_TYPES).to eq(%w[quality_analysis link_suggestion impact_analysis])
    end
  end

  describe "scopes" do
    let(:requirement) { create(:requirement) }

    describe ".for_type" do
      it "filters by analysis type" do
        qa = create(:ai_analysis_result, requirement: requirement, analysis_type: "quality_analysis")
        create(:ai_analysis_result, requirement: requirement, analysis_type: "link_suggestion")
        expect(described_class.for_type("quality_analysis")).to eq([qa])
      end
    end

    describe ".latest_completed" do
      it "returns completed results ordered by completed_at desc" do
        req2 = create(:requirement)
        old = create(:ai_analysis_result, :completed, requirement: requirement, completed_at: 2.hours.ago)
        recent = create(:ai_analysis_result, :completed, requirement: req2, analysis_type: "quality_analysis", completed_at: 1.hour.ago)
        create(:ai_analysis_result, requirement: create(:requirement), analysis_type: "quality_analysis", status: :pending)
        expect(described_class.latest_completed).to eq([recent, old])
      end
    end

    describe ".stale" do
      it "returns results older than threshold" do
        stale = create(:ai_analysis_result, :completed, requirement: requirement, completed_at: 48.hours.ago)
        create(:ai_analysis_result, :completed, requirement: create(:requirement), completed_at: 1.hour.ago)
        expect(described_class.stale(24.hours)).to eq([stale])
      end
    end
  end

  describe ".store_result!" do
    let(:requirement) { create(:requirement) }

    it "creates a new completed result" do
      result_data = { "overall_score" => 85 }
      record = described_class.store_result!(requirement, "quality_analysis", result_data)

      expect(record).to be_persisted
      expect(record.status).to eq("completed")
      expect(record.result_data).to eq(result_data)
      expect(record.error_message).to be_nil
      expect(record.completed_at).to be_present
    end

    it "upserts an existing result" do
      old = create(:ai_analysis_result, requirement: requirement, analysis_type: "quality_analysis", status: :failed, error_message: "timeout")
      new_data = { "overall_score" => 90 }
      record = described_class.store_result!(requirement, "quality_analysis", new_data)

      expect(record.id).to eq(old.id)
      expect(record.status).to eq("completed")
      expect(record.result_data).to eq(new_data)
      expect(record.error_message).to be_nil
    end

    it "clears previous error message on success" do
      create(:ai_analysis_result, :failed, requirement: requirement, analysis_type: "quality_analysis")
      record = described_class.store_result!(requirement, "quality_analysis", { "score" => 100 })
      expect(record.error_message).to be_nil
    end
  end

  describe ".store_failure!" do
    let(:requirement) { create(:requirement) }

    it "creates a failed result with error message" do
      record = described_class.store_failure!(requirement, "quality_analysis", "Service unavailable")

      expect(record).to be_persisted
      expect(record.status).to eq("failed")
      expect(record.error_message).to eq("Service unavailable")
      expect(record.completed_at).to be_present
    end

    it "upserts an existing result to failed" do
      old = create(:ai_analysis_result, :completed, requirement: requirement, analysis_type: "quality_analysis")
      record = described_class.store_failure!(requirement, "quality_analysis", "Timeout error")

      expect(record.id).to eq(old.id)
      expect(record.status).to eq("failed")
      expect(record.error_message).to eq("Timeout error")
    end
  end

  describe ".mark_running!" do
    let(:requirement) { create(:requirement) }

    it "creates a running result" do
      record = described_class.mark_running!(requirement, "quality_analysis")

      expect(record).to be_persisted
      expect(record.status).to eq("running")
      expect(record.error_message).to be_nil
    end

    it "upserts an existing failed result to running" do
      old = create(:ai_analysis_result, :failed, requirement: requirement, analysis_type: "quality_analysis")
      record = described_class.mark_running!(requirement, "quality_analysis")

      expect(record.id).to eq(old.id)
      expect(record.status).to eq("running")
      expect(record.error_message).to be_nil
    end
  end

  describe "#stale?" do
    it "returns true when completed_at is nil" do
      result = build(:ai_analysis_result, completed_at: nil)
      expect(result.stale?).to be true
    end

    it "returns true when completed_at is older than threshold" do
      result = build(:ai_analysis_result, completed_at: 48.hours.ago)
      expect(result.stale?(24.hours)).to be true
    end

    it "returns false when completed_at is within threshold" do
      result = build(:ai_analysis_result, completed_at: 1.hour.ago)
      expect(result.stale?(24.hours)).to be false
    end

    it "uses default 24-hour threshold" do
      result = build(:ai_analysis_result, completed_at: 25.hours.ago)
      expect(result.stale?).to be true
    end
  end

  describe "#quality_score" do
    it "returns the overall score for completed quality analysis" do
      result = build(:ai_analysis_result, :with_quality_result)
      expect(result.quality_score).to eq(75)
    end

    it "returns nil for non-quality analysis" do
      result = build(:ai_analysis_result, :with_link_suggestions)
      expect(result.quality_score).to be_nil
    end

    it "returns nil for non-completed quality analysis" do
      result = build(:ai_analysis_result, :running, analysis_type: "quality_analysis")
      expect(result.quality_score).to be_nil
    end

    it "handles string keys in result_data" do
      result = build(:ai_analysis_result, :completed, analysis_type: "quality_analysis",
                     result_data: { "overall_score" => 85 })
      expect(result.quality_score).to eq(85)
    end
  end

  describe "#suggestions_count" do
    it "returns the number of suggestions for completed link suggestion" do
      result = build(:ai_analysis_result, :with_link_suggestions)
      expect(result.suggestions_count).to eq(2)
    end

    it "returns nil for non-link-suggestion analysis" do
      result = build(:ai_analysis_result, :with_quality_result)
      expect(result.suggestions_count).to be_nil
    end

    it "returns 0 when suggestions array is empty" do
      result = build(:ai_analysis_result, :completed, analysis_type: "link_suggestion",
                     result_data: { "suggestions" => [] })
      expect(result.suggestions_count).to eq(0)
    end

    it "returns 0 when suggestions key is missing" do
      result = build(:ai_analysis_result, :completed, analysis_type: "link_suggestion",
                     result_data: {})
      expect(result.suggestions_count).to eq(0)
    end
  end

  describe "#impacts_count" do
    it "returns the number of impacts for completed impact analysis" do
      result = build(:ai_analysis_result, :with_impact_result)
      expect(result.impacts_count).to eq(1)
    end

    it "returns nil for non-impact-analysis" do
      result = build(:ai_analysis_result, :with_quality_result)
      expect(result.impacts_count).to be_nil
    end

    it "returns 0 when impacts array is empty" do
      result = build(:ai_analysis_result, :completed, analysis_type: "impact_analysis",
                     result_data: { "impacts" => [] })
      expect(result.impacts_count).to eq(0)
    end
  end

  describe "requirement association" do
    it "is accessible from requirement" do
      requirement = create(:requirement)
      result = create(:ai_analysis_result, requirement: requirement)
      expect(requirement.ai_analysis_results).to include(result)
    end

    it "is destroyed when requirement is destroyed" do
      requirement = create(:requirement)
      create(:ai_analysis_result, requirement: requirement)
      expect { requirement.destroy }.to change(described_class, :count).by(-1)
    end

    it "supports multiple analysis types per requirement" do
      requirement = create(:requirement)
      create(:ai_analysis_result, requirement: requirement, analysis_type: "quality_analysis")
      create(:ai_analysis_result, requirement: requirement, analysis_type: "link_suggestion")
      create(:ai_analysis_result, requirement: requirement, analysis_type: "impact_analysis")
      expect(requirement.ai_analysis_results.count).to eq(3)
    end
  end
end
