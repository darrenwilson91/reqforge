require "rails_helper"

RSpec.describe LinkSuggestionJob, type: :job do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:project) { create(:project, organization: organization) }
  let(:requirement_module) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: requirement_module) }
  let(:requirement) { create(:requirement, project: project, section: section, created_by: user) }

  let(:suggestion_result) do
    {
      suggestions: [
        { target_uid: "PRJ-002", link_type: "derives_from", confidence: 0.85, rationale: "High-level parent requirement" },
        { target_uid: "PRJ-003", link_type: "satisfies", confidence: 0.72, rationale: "Fulfills safety constraint" }
      ]
    }
  end

  before do
    allow_any_instance_of(LinkSuggester).to receive(:suggest).and_return(suggestion_result)
  end

  describe "#perform" do
    it "finds the requirement and runs link suggestion" do
      suggester = instance_double(LinkSuggester)
      allow(LinkSuggester).to receive(:new).and_return(suggester)
      expect(suggester).to receive(:suggest).with(requirement).and_return(suggestion_result)

      described_class.new.perform(requirement.id)
    end

    it "logs the result when AiAnalysisResult is not defined" do
      expect(Rails.logger).to receive(:info).with(/LinkSuggestionJob.*#{requirement.uid}.*2 suggestions/)

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
  end

  describe "error handling" do
    it "discards the job when the requirement is not found" do
      expect {
        described_class.perform_now(0)
      }.not_to raise_error
    end

    it "retries on LinkSuggester::Error" do
      allow_any_instance_of(LinkSuggester).to receive(:suggest).and_raise(LinkSuggester::Error, "Service unavailable")

      expect {
        described_class.perform_now(requirement.id)
      }.to have_enqueued_job(described_class).with(requirement.id)
    end

    it "retries on LlmService::TimeoutError" do
      allow_any_instance_of(LinkSuggester).to receive(:suggest).and_raise(LlmService::TimeoutError, "Timeout")

      expect {
        described_class.perform_now(requirement.id)
      }.to have_enqueued_job(described_class).with(requirement.id)
    end
  end
end
