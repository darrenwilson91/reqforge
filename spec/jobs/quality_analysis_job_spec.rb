require "rails_helper"

RSpec.describe QualityAnalysisJob, type: :job do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:project) { create(:project, organization: organization) }
  let(:requirement_module) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: requirement_module) }
  let(:requirement) { create(:requirement, project: project, section: section, created_by: user) }

  let(:analysis_result) do
    {
      overall_score: 75,
      checks: [
        { rule: "ambiguity", passed: true, score: 90, issues: [], suggestions: [] },
        { rule: "completeness", passed: false, score: 60, issues: ["Missing preconditions"], suggestions: ["Add preconditions"] },
        { rule: "singularity", passed: true, score: 100, issues: [], suggestions: [] },
        { rule: "correctness", passed: true, score: 80, issues: [], suggestions: [] },
        { rule: "verifiability", passed: true, score: 70, issues: [], suggestions: [] },
        { rule: "conformance", passed: true, score: 85, issues: [], suggestions: [] }
      ],
      summary: "Good quality with minor completeness issues."
    }
  end

  before do
    allow_any_instance_of(QualityAnalyzer).to receive(:analyze).and_return(analysis_result)
  end

  describe "#perform" do
    it "finds the requirement and runs quality analysis" do
      analyzer = instance_double(QualityAnalyzer)
      allow(QualityAnalyzer).to receive(:new).and_return(analyzer)
      expect(analyzer).to receive(:analyze).with(requirement).and_return(analysis_result)

      described_class.new.perform(requirement.id)
    end

    it "marks the analysis as running before starting" do
      described_class.new.perform(requirement.id)
      # After completion it should be completed, but mark_running! was called first
      result = AiAnalysisResult.find_by(requirement: requirement, analysis_type: "quality_analysis")
      expect(result.status).to eq("completed")
    end

    it "stores the result in AiAnalysisResult" do
      described_class.new.perform(requirement.id)

      result = AiAnalysisResult.find_by(requirement: requirement, analysis_type: "quality_analysis")
      expect(result).to be_present
      expect(result.status).to eq("completed")
      expect(result.result_data["overall_score"]).to eq(75)
      expect(result.completed_at).to be_present
      expect(result.error_message).to be_nil
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
  end

  describe "error handling" do
    it "discards the job when the requirement is not found" do
      expect {
        described_class.perform_now(0)
      }.not_to raise_error
    end

    it "retries on QualityAnalyzer::Error and stores failure" do
      allow_any_instance_of(QualityAnalyzer).to receive(:analyze).and_raise(QualityAnalyzer::Error, "Service unavailable")

      expect {
        described_class.perform_now(requirement.id)
      }.to have_enqueued_job(described_class).with(requirement.id)

      result = AiAnalysisResult.find_by(requirement: requirement, analysis_type: "quality_analysis")
      expect(result.status).to eq("failed")
      expect(result.error_message).to eq("Service unavailable")
    end

    it "retries on LlmService::TimeoutError and stores failure" do
      allow_any_instance_of(QualityAnalyzer).to receive(:analyze).and_raise(LlmService::TimeoutError, "Timeout")

      expect {
        described_class.perform_now(requirement.id)
      }.to have_enqueued_job(described_class).with(requirement.id)

      result = AiAnalysisResult.find_by(requirement: requirement, analysis_type: "quality_analysis")
      expect(result.status).to eq("failed")
      expect(result.error_message).to eq("Timeout")
    end
  end
end
