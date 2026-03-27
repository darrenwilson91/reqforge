require "rails_helper"

RSpec.describe ImpactAnalysisJob, type: :job do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:project) { create(:project, organization: organization) }
  let(:requirement_module) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: requirement_module) }
  let(:requirement) { create(:requirement, project: project, section: section, created_by: user) }

  let(:impact_result) do
    {
      impacts: [
        { target_uid: "PRJ-002", severity: "high", impact_type: "direct", description: "Directly derived requirement needs update" },
        { target_uid: "PRJ-003", severity: "medium", impact_type: "indirect", description: "Verification test case may need revision" }
      ],
      summary: "2 requirements affected by this change.",
      risk_level: "significant"
    }
  end

  before do
    allow_any_instance_of(ImpactAnalyzer).to receive(:analyze).and_return(impact_result)
  end

  describe "#perform" do
    it "finds the requirement and runs impact analysis without changes" do
      analyzer = instance_double(ImpactAnalyzer)
      allow(ImpactAnalyzer).to receive(:new).and_return(analyzer)
      expect(analyzer).to receive(:analyze).with(requirement, changes: nil).and_return(impact_result)

      described_class.new.perform(requirement.id)
    end

    it "passes changes hash to the analyzer" do
      changes = { "title" => ["Old Title", "New Title"], "status" => ["draft", "in_review"] }
      analyzer = instance_double(ImpactAnalyzer)
      allow(ImpactAnalyzer).to receive(:new).and_return(analyzer)
      expect(analyzer).to receive(:analyze).with(requirement, changes: { title: ["Old Title", "New Title"], status: ["draft", "in_review"] }).and_return(impact_result)

      described_class.new.perform(requirement.id, changes)
    end

    it "handles nil changes gracefully" do
      analyzer = instance_double(ImpactAnalyzer)
      allow(ImpactAnalyzer).to receive(:new).and_return(analyzer)
      expect(analyzer).to receive(:analyze).with(requirement, changes: nil).and_return(impact_result)

      described_class.new.perform(requirement.id, nil)
    end

    it "logs the result when AiAnalysisResult is not defined" do
      expect(Rails.logger).to receive(:info).with(/ImpactAnalysisJob.*#{requirement.uid}.*2 impacts.*risk=significant/)

      described_class.new.perform(requirement.id)
    end
  end

  describe "queue" do
    it "enqueues in the ai_analysis queue" do
      expect {
        described_class.perform_later(requirement.id)
      }.to have_enqueued_job(described_class).on_queue("ai_analysis")
    end
  end

  describe "enqueuing" do
    it "can be enqueued with a requirement ID" do
      expect {
        described_class.perform_later(requirement.id)
      }.to have_enqueued_job(described_class).with(requirement.id)
    end

    it "can be enqueued with a requirement ID and changes" do
      changes = { "title" => ["Old", "New"] }
      expect {
        described_class.perform_later(requirement.id, changes)
      }.to have_enqueued_job(described_class).with(requirement.id, changes)
    end
  end

  describe "error handling" do
    it "discards the job when the requirement is not found" do
      expect {
        described_class.perform_now(0)
      }.not_to raise_error
    end

    it "retries on ImpactAnalyzer::Error" do
      allow_any_instance_of(ImpactAnalyzer).to receive(:analyze).and_raise(ImpactAnalyzer::Error, "Service unavailable")

      expect {
        described_class.perform_now(requirement.id)
      }.to have_enqueued_job(described_class).with(requirement.id)
    end

    it "retries on LlmService::TimeoutError" do
      allow_any_instance_of(ImpactAnalyzer).to receive(:analyze).and_raise(LlmService::TimeoutError, "Timeout")

      expect {
        described_class.perform_now(requirement.id)
      }.to have_enqueued_job(described_class).with(requirement.id)
    end
  end
end
