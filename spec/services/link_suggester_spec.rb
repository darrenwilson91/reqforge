require "rails_helper"

RSpec.describe LinkSuggester do
  let(:llm_service) { instance_double(LlmService) }
  subject(:suggester) { described_class.new(llm_service: llm_service) }

  let(:project) { create(:project) }
  let(:section) { create(:section, requirement_module: create(:requirement_module, project: project)) }

  let(:source_requirement) do
    create(:requirement,
      project: project,
      section: section,
      uid: "SYS-0001",
      title: "Brake system response time",
      body: "The brake system shall respond to pedal input within 150 milliseconds under all operating conditions.",
      requirement_type: "safety",
      asil_level: "asil_d",
      status: "approved"
    )
  end

  let(:candidate1) do
    create(:requirement,
      project: project,
      section: section,
      uid: "SYS-0002",
      title: "Brake actuator control",
      body: "The brake actuator shall apply braking force proportional to pedal displacement.",
      requirement_type: "functional",
      asil_level: "asil_c"
    )
  end

  let(:candidate2) do
    create(:requirement,
      project: project,
      section: section,
      uid: "SYS-0003",
      title: "Brake system test specification",
      body: "The brake response time shall be verified through hardware-in-the-loop testing.",
      requirement_type: "non_functional",
      asil_level: "asil_d"
    )
  end

  let(:candidate3) do
    create(:requirement,
      project: project,
      section: section,
      uid: "SYS-0004",
      title: "Dashboard display brightness",
      body: "The dashboard display shall adjust brightness automatically based on ambient light.",
      requirement_type: "functional",
      asil_level: "qm"
    )
  end

  let(:good_llm_response) do
    {
      "suggestions" => [
        {
          "target_uid" => "SYS-0003",
          "link_type" => "verifies",
          "confidence" => 0.92,
          "rationale" => "SYS-0003 specifies verification testing for brake response time, directly testing SYS-0001."
        },
        {
          "target_uid" => "SYS-0002",
          "link_type" => "derives_from",
          "confidence" => 0.78,
          "rationale" => "Both relate to brake system behavior; actuator control derives from response time requirement."
        }
      ]
    }
  end

  describe "#initialize" do
    it "accepts a custom LLM service" do
      custom = LlmService.new(timeout: 120)
      suggester = described_class.new(llm_service: custom)
      expect(suggester.llm_service).to eq(custom)
    end

    it "creates a default LLM service if none provided" do
      suggester = described_class.new
      expect(suggester.llm_service).to be_a(LlmService)
    end

    it "uses 90 second timeout for default LLM service" do
      suggester = described_class.new
      expect(suggester.llm_service.timeout).to eq(90)
    end
  end

  describe "#suggest" do
    context "with a well-formed LLM response" do
      before do
        allow(llm_service).to receive(:call).and_return(good_llm_response)
      end

      it "returns suggestions sorted by confidence descending" do
        candidates = [candidate1, candidate2, candidate3]
        result = suggester.suggest(source_requirement, candidates: candidates)
        confidences = result[:suggestions].map { |s| s[:confidence] }
        expect(confidences).to eq([0.92, 0.78])
      end

      it "returns target UIDs" do
        candidates = [candidate1, candidate2, candidate3]
        result = suggester.suggest(source_requirement, candidates: candidates)
        uids = result[:suggestions].map { |s| s[:target_uid] }
        expect(uids).to eq(%w[SYS-0003 SYS-0002])
      end

      it "returns link types" do
        candidates = [candidate1, candidate2, candidate3]
        result = suggester.suggest(source_requirement, candidates: candidates)
        types = result[:suggestions].map { |s| s[:link_type] }
        expect(types).to eq(%w[verifies derives_from])
      end

      it "returns rationale for each suggestion" do
        candidates = [candidate1, candidate2, candidate3]
        result = suggester.suggest(source_requirement, candidates: candidates)
        expect(result[:suggestions].first[:rationale]).to include("verification testing")
      end

      it "includes source requirement details in prompt" do
        candidates = [candidate1, candidate2]
        suggester.suggest(source_requirement, candidates: candidates)
        expect(llm_service).to have_received(:call).with(
          a_string_including("SYS-0001", "Brake system response time", "150 milliseconds"),
          system_prompt: described_class::SYSTEM_PROMPT
        )
      end

      it "includes source requirement type and ASIL in prompt" do
        candidates = [candidate1]
        suggester.suggest(source_requirement, candidates: candidates)
        expect(llm_service).to have_received(:call).with(
          a_string_including("Safety", "ASIL_D"),
          system_prompt: anything
        )
      end

      it "includes candidate requirements in prompt" do
        candidates = [candidate1, candidate2]
        suggester.suggest(source_requirement, candidates: candidates)
        expect(llm_service).to have_received(:call).with(
          a_string_including("SYS-0002", "Brake actuator control", "SYS-0003", "Brake system test specification"),
          system_prompt: anything
        )
      end

      it "labels source and candidates in prompt" do
        candidates = [candidate1]
        suggester.suggest(source_requirement, candidates: candidates)
        expect(llm_service).to have_received(:call).with(
          a_string_including("[SOURCE]", "[CANDIDATE 1]"),
          system_prompt: anything
        )
      end
    end

    context "with auto-resolved candidates from project" do
      before do
        # Create candidates in the project
        candidate1
        candidate2
        candidate3
        allow(llm_service).to receive(:call).and_return(good_llm_response)
      end

      it "automatically finds candidates from the same project" do
        result = suggester.suggest(source_requirement)
        expect(result[:suggestions]).not_to be_empty
      end

      it "excludes the source requirement from candidates" do
        suggester.suggest(source_requirement)
        expect(llm_service).to have_received(:call) do |prompt, **_kwargs|
          # SYS-0001 should appear as SOURCE but NOT as a CANDIDATE
          candidate_section = prompt.split("---").last
          expect(candidate_section).not_to include("SYS-0001")
        end
      end

      it "excludes obsolete requirements from auto-resolved candidates" do
        obsolete_req = create(:requirement, :obsolete, project: project, section: section, uid: "SYS-0005", title: "Old requirement")
        suggester.suggest(source_requirement)
        expect(llm_service).to have_received(:call) do |prompt, **_kwargs|
          expect(prompt).not_to include("SYS-0005")
        end
      end
    end

    context "when there are no candidates" do
      before do
        allow(llm_service).to receive(:call)
      end

      it "returns empty suggestions without calling LLM" do
        result = suggester.suggest(source_requirement, candidates: [])
        expect(result).to eq({ suggestions: [] })
        expect(llm_service).not_to have_received(:call)
      end
    end

    context "when requirement has no title" do
      let(:no_title_req) do
        build(:requirement, uid: "SYS-0099", title: nil)
      end

      it "raises LinkSuggester::Error" do
        expect { suggester.suggest(no_title_req) }.to raise_error(
          LinkSuggester::Error, /must have a title/
        )
      end
    end

    context "when LLM returns suggestions with unknown UIDs" do
      let(:unknown_uid_response) do
        {
          "suggestions" => [
            { "target_uid" => "UNKNOWN-001", "link_type" => "satisfies", "confidence" => 0.8, "rationale" => "Some reason" },
            { "target_uid" => "SYS-0002", "link_type" => "derives_from", "confidence" => 0.7, "rationale" => "Valid link" }
          ]
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(unknown_uid_response)
      end

      it "filters out suggestions with UIDs not in candidates" do
        candidates = [candidate1, candidate2]
        result = suggester.suggest(source_requirement, candidates: candidates)
        uids = result[:suggestions].map { |s| s[:target_uid] }
        expect(uids).to eq(%w[SYS-0002])
        expect(uids).not_to include("UNKNOWN-001")
      end
    end

    context "when LLM returns suggestions with invalid link types" do
      let(:invalid_type_response) do
        {
          "suggestions" => [
            { "target_uid" => "SYS-0002", "link_type" => "made_up_type", "confidence" => 0.8, "rationale" => "Invalid" },
            { "target_uid" => "SYS-0003", "link_type" => "verifies", "confidence" => 0.7, "rationale" => "Valid" }
          ]
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(invalid_type_response)
      end

      it "filters out suggestions with unknown link types" do
        candidates = [candidate1, candidate2, candidate3]
        result = suggester.suggest(source_requirement, candidates: candidates)
        types = result[:suggestions].map { |s| s[:link_type] }
        expect(types).to eq(%w[verifies])
      end
    end

    context "when LLM returns low confidence suggestions" do
      let(:low_confidence_response) do
        {
          "suggestions" => [
            { "target_uid" => "SYS-0002", "link_type" => "derives_from", "confidence" => 0.1, "rationale" => "Weak link" },
            { "target_uid" => "SYS-0003", "link_type" => "verifies", "confidence" => 0.29, "rationale" => "Below threshold" },
            { "target_uid" => "SYS-0004", "link_type" => "satisfies", "confidence" => 0.3, "rationale" => "At threshold" }
          ]
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(low_confidence_response)
      end

      it "filters out suggestions below 0.3 confidence" do
        candidates = [candidate1, candidate2, candidate3]
        result = suggester.suggest(source_requirement, candidates: candidates)
        expect(result[:suggestions].length).to eq(1)
        expect(result[:suggestions].first[:target_uid]).to eq("SYS-0004")
      end

      it "keeps suggestions at exactly 0.3 confidence" do
        candidates = [candidate1, candidate2, candidate3]
        result = suggester.suggest(source_requirement, candidates: candidates)
        expect(result[:suggestions].first[:confidence]).to eq(0.3)
      end
    end

    context "when LLM returns confidence out of range" do
      let(:out_of_range_response) do
        {
          "suggestions" => [
            { "target_uid" => "SYS-0002", "link_type" => "derives_from", "confidence" => 1.5, "rationale" => "High" },
            { "target_uid" => "SYS-0003", "link_type" => "verifies", "confidence" => -0.2, "rationale" => "Negative" }
          ]
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(out_of_range_response)
      end

      it "clamps confidence to 0.0-1.0 range" do
        candidates = [candidate1, candidate2, candidate3]
        result = suggester.suggest(source_requirement, candidates: candidates)
        confidences = result[:suggestions].map { |s| s[:confidence] }
        expect(confidences).to eq([1.0]) # -0.2 clamped to 0.0 which is < 0.3 threshold, filtered out
      end

      it "filters out negative confidence after clamping (below threshold)" do
        candidates = [candidate1, candidate2, candidate3]
        result = suggester.suggest(source_requirement, candidates: candidates)
        uids = result[:suggestions].map { |s| s[:target_uid] }
        expect(uids).not_to include("SYS-0003")
      end
    end

    context "when LLM returns nil confidence" do
      let(:nil_confidence_response) do
        {
          "suggestions" => [
            { "target_uid" => "SYS-0002", "link_type" => "derives_from", "confidence" => nil, "rationale" => "No confidence" }
          ]
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(nil_confidence_response)
      end

      it "treats nil confidence as 0.0 and filters it out" do
        candidates = [candidate1]
        result = suggester.suggest(source_requirement, candidates: candidates)
        expect(result[:suggestions]).to be_empty
      end
    end

    context "when LLM returns plain text instead of JSON" do
      before do
        allow(llm_service).to receive(:call).and_return({ "text" => "I cannot analyze these requirements." })
      end

      it "returns empty suggestions" do
        candidates = [candidate1]
        result = suggester.suggest(source_requirement, candidates: candidates)
        expect(result[:suggestions]).to be_empty
      end
    end

    context "when LLM returns empty response" do
      before do
        allow(llm_service).to receive(:call).and_return(nil)
      end

      it "returns empty suggestions" do
        candidates = [candidate1]
        result = suggester.suggest(source_requirement, candidates: candidates)
        expect(result[:suggestions]).to be_empty
      end
    end

    context "when LLM returns no suggestions array" do
      before do
        allow(llm_service).to receive(:call).and_return({ "analysis" => "no links found" })
      end

      it "returns empty suggestions" do
        candidates = [candidate1]
        result = suggester.suggest(source_requirement, candidates: candidates)
        expect(result[:suggestions]).to be_empty
      end
    end

    context "when LLM returns suggestions with missing rationale" do
      let(:no_rationale_response) do
        {
          "suggestions" => [
            { "target_uid" => "SYS-0002", "link_type" => "derives_from", "confidence" => 0.8 }
          ]
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(no_rationale_response)
      end

      it "provides a default rationale" do
        candidates = [candidate1]
        result = suggester.suggest(source_requirement, candidates: candidates)
        expect(result[:suggestions].first[:rationale]).to eq("Semantic similarity detected.")
      end
    end

    context "when LLM returns mixed case link types" do
      let(:mixed_case_response) do
        {
          "suggestions" => [
            { "target_uid" => "SYS-0002", "link_type" => "Derives_From", "confidence" => 0.8, "rationale" => "Mixed case" }
          ]
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(mixed_case_response)
      end

      it "normalizes link types to lowercase" do
        candidates = [candidate1]
        result = suggester.suggest(source_requirement, candidates: candidates)
        expect(result[:suggestions].first[:link_type]).to eq("derives_from")
      end
    end

    context "when LLM service raises an error" do
      before do
        allow(llm_service).to receive(:call).and_raise(LlmService::Error, "CLI exited with status 1")
      end

      it "raises LinkSuggester::Error" do
        candidates = [candidate1]
        expect { suggester.suggest(source_requirement, candidates: candidates) }.to raise_error(
          LinkSuggester::Error, /Link suggestion failed: CLI exited with status 1/
        )
      end
    end

    context "when LLM service times out" do
      before do
        allow(llm_service).to receive(:call).and_raise(LlmService::TimeoutError, "timed out after 90 seconds")
      end

      it "raises LinkSuggester::Error" do
        candidates = [candidate1]
        expect { suggester.suggest(source_requirement, candidates: candidates) }.to raise_error(
          LinkSuggester::Error, /Link suggestion failed: timed out/
        )
      end
    end

    context "when candidates include the source requirement" do
      before do
        allow(llm_service).to receive(:call).and_return({ "suggestions" => [] })
      end

      it "excludes the source from explicit candidates" do
        candidates = [source_requirement, candidate1]
        suggester.suggest(source_requirement, candidates: candidates)
        expect(llm_service).to have_received(:call) do |prompt, **_kwargs|
          # Only candidate1 should appear, not the source
          expect(prompt.scan(/\[CANDIDATE/).length).to eq(1)
        end
      end
    end

    context "with all seven valid link types" do
      let(:all_types_response) do
        {
          "suggestions" => LinkSuggester::VALID_LINK_TYPES.each_with_index.map do |type, i|
            { "target_uid" => "SYS-0002", "link_type" => type, "confidence" => (0.9 - i * 0.05).round(2), "rationale" => "Type #{type}" }
          end
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(all_types_response)
      end

      it "accepts all seven link types" do
        candidates = [candidate1]
        result = suggester.suggest(source_requirement, candidates: candidates)
        types = result[:suggestions].map { |s| s[:link_type] }
        expect(types).to eq(LinkSuggester::VALID_LINK_TYPES)
      end
    end

    context "when requirement has no body" do
      let(:no_body_req) do
        create(:requirement, project: project, section: section, uid: "SYS-0010", title: "No body requirement", body: nil)
      end

      before do
        allow(llm_service).to receive(:call).and_return({ "suggestions" => [] })
      end

      it "omits body from the prompt" do
        candidates = [candidate1]
        suggester.suggest(no_body_req, candidates: candidates)
        expect(llm_service).to have_received(:call) do |prompt, **_kwargs|
          source_section = prompt.split("---").first
          expect(source_section).not_to include("Body:")
        end
      end
    end

    context "confidence rounding" do
      let(:precision_response) do
        {
          "suggestions" => [
            { "target_uid" => "SYS-0002", "link_type" => "derives_from", "confidence" => 0.756, "rationale" => "Precise" }
          ]
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(precision_response)
      end

      it "rounds confidence to 2 decimal places" do
        candidates = [candidate1]
        result = suggester.suggest(source_requirement, candidates: candidates)
        expect(result[:suggestions].first[:confidence]).to eq(0.76)
      end
    end
  end

  describe "VALID_LINK_TYPES constant" do
    it "defines all seven link types" do
      expect(described_class::VALID_LINK_TYPES).to eq(
        %w[derives_from satisfies verifies conflicts_with refines implements parent_child]
      )
    end

    it "matches TraceabilityLink link_type enum keys" do
      expect(described_class::VALID_LINK_TYPES).to match_array(TraceabilityLink.link_types.keys)
    end
  end

  describe "MAX_CANDIDATES constant" do
    it "limits auto-resolved candidates to 50" do
      expect(described_class::MAX_CANDIDATES).to eq(50)
    end
  end

  describe "SYSTEM_PROMPT constant" do
    it "includes all link type definitions" do
      %w[derives_from satisfies verifies conflicts_with refines implements parent_child].each do |type|
        expect(described_class::SYSTEM_PROMPT).to include(type)
      end
    end

    it "specifies JSON response format" do
      expect(described_class::SYSTEM_PROMPT).to include("suggestions")
      expect(described_class::SYSTEM_PROMPT).to include("target_uid")
      expect(described_class::SYSTEM_PROMPT).to include("confidence")
    end

    it "specifies minimum confidence threshold" do
      expect(described_class::SYSTEM_PROMPT).to include("0.3")
    end
  end
end
