require "rails_helper"

RSpec.describe RequirementGenerator do
  let(:mock_llm) { instance_double(LlmService) }
  subject(:generator) { described_class.new(llm_service: mock_llm) }

  describe "#initialize" do
    it "uses provided llm_service" do
      expect(generator.llm_service).to eq(mock_llm)
    end

    it "creates default LlmService with 90s timeout" do
      expect(LlmService).to receive(:new).with(timeout: 90).and_return(mock_llm)
      described_class.new
    end
  end

  describe "#generate" do
    let(:description) { "The brake system shall detect wheel lock and release brake pressure within 50ms" }

    context "with a good LLM response" do
      let(:llm_response) do
        {
          "requirements" => [
            {
              "title" => "Wheel Lock Detection",
              "body" => "The brake control unit shall detect wheel lock conditions within 10ms of onset.",
              "requirement_type" => "safety",
              "priority" => "must_have",
              "asil_level" => "asil_d",
              "rationale" => "Core ABS safety function requiring fastest detection time."
            },
            {
              "title" => "Brake Pressure Release",
              "body" => "The brake control unit shall release brake pressure within 50ms of wheel lock detection.",
              "requirement_type" => "functional",
              "priority" => "must_have",
              "asil_level" => "asil_c",
              "rationale" => "Implements the pressure release timing requirement from the description."
            }
          ]
        }
      end

      before { allow(mock_llm).to receive(:call).and_return(llm_response) }

      it "returns normalized requirements" do
        result = generator.generate(description)
        expect(result[:requirements].length).to eq(2)
      end

      it "preserves requirement titles" do
        result = generator.generate(description)
        expect(result[:requirements].map { |r| r[:title] }).to eq(
          ["Wheel Lock Detection", "Brake Pressure Release"]
        )
      end

      it "preserves requirement bodies" do
        result = generator.generate(description)
        expect(result[:requirements].first[:body]).to include("wheel lock conditions within 10ms")
      end

      it "preserves requirement types" do
        result = generator.generate(description)
        expect(result[:requirements].first[:requirement_type]).to eq("safety")
        expect(result[:requirements].last[:requirement_type]).to eq("functional")
      end

      it "preserves priorities" do
        result = generator.generate(description)
        expect(result[:requirements].first[:priority]).to eq("must_have")
      end

      it "preserves ASIL levels" do
        result = generator.generate(description)
        expect(result[:requirements].first[:asil_level]).to eq("asil_d")
        expect(result[:requirements].last[:asil_level]).to eq("asil_c")
      end

      it "preserves rationale" do
        result = generator.generate(description)
        expect(result[:requirements].first[:rationale]).to include("ABS safety function")
      end

      it "includes description in prompt" do
        expect(mock_llm).to receive(:call).with(
          a_string_including(description),
          system_prompt: described_class::SYSTEM_PROMPT
        ).and_return(llm_response)
        generator.generate(description)
      end

      it "uses the INCOSE system prompt" do
        expect(mock_llm).to receive(:call).with(
          anything,
          system_prompt: a_string_including("INCOSE")
        ).and_return(llm_response)
        generator.generate(description)
      end
    end

    context "with project context" do
      let(:llm_response) { { "requirements" => [{ "title" => "Test", "body" => "Shall test.", "requirement_type" => "functional", "priority" => "should_have", "asil_level" => "qm", "rationale" => "Test" }] } }

      before { allow(mock_llm).to receive(:call).and_return(llm_response) }

      it "includes project name in prompt" do
        expect(mock_llm).to receive(:call).with(
          a_string_including("Project: ABS Control System"),
          anything
        ).and_return(llm_response)
        generator.generate(description, context: { project_name: "ABS Control System" })
      end

      it "includes domain in prompt" do
        expect(mock_llm).to receive(:call).with(
          a_string_including("Domain: Automotive Braking"),
          anything
        ).and_return(llm_response)
        generator.generate(description, context: { project_name: "ABS", domain: "Automotive Braking" })
      end

      it "includes existing types in prompt" do
        expect(mock_llm).to receive(:call).with(
          a_string_including("functional, safety"),
          anything
        ).and_return(llm_response)
        generator.generate(description, context: { existing_types: %w[functional safety] })
      end

      it "includes module name in prompt" do
        expect(mock_llm).to receive(:call).with(
          a_string_including("Target module: Brake Control"),
          anything
        ).and_return(llm_response)
        generator.generate(description, context: { module_name: "Brake Control" })
      end

      it "includes section name in prompt" do
        expect(mock_llm).to receive(:call).with(
          a_string_including("Target section: Safety Requirements"),
          anything
        ).and_return(llm_response)
        generator.generate(description, context: { section_name: "Safety Requirements" })
      end

      it "omits context section when no context provided" do
        expect(mock_llm).to receive(:call) do |prompt, **_opts|
          expect(prompt).not_to include("Project context")
          llm_response
        end
        generator.generate(description)
      end
    end

    context "with blank description" do
      it "raises an error" do
        expect { generator.generate("") }.to raise_error(RequirementGenerator::Error, "Description cannot be blank")
      end

      it "raises for nil description" do
        expect { generator.generate(nil) }.to raise_error(RequirementGenerator::Error, "Description cannot be blank")
      end

      it "raises for whitespace-only description" do
        expect { generator.generate("   ") }.to raise_error(RequirementGenerator::Error, "Description cannot be blank")
      end
    end

    context "with invalid requirement_type" do
      before do
        allow(mock_llm).to receive(:call).and_return({
          "requirements" => [{ "title" => "Test Req", "body" => "Shall test.", "requirement_type" => "invalid_type", "priority" => "must_have", "asil_level" => "qm", "rationale" => "Test" }]
        })
      end

      it "defaults to functional" do
        result = generator.generate(description)
        expect(result[:requirements].first[:requirement_type]).to eq("functional")
      end
    end

    context "with invalid priority" do
      before do
        allow(mock_llm).to receive(:call).and_return({
          "requirements" => [{ "title" => "Test Req", "body" => "Shall test.", "requirement_type" => "functional", "priority" => "critical", "asil_level" => "qm", "rationale" => "Test" }]
        })
      end

      it "defaults to should_have" do
        result = generator.generate(description)
        expect(result[:requirements].first[:priority]).to eq("should_have")
      end
    end

    context "with invalid asil_level" do
      before do
        allow(mock_llm).to receive(:call).and_return({
          "requirements" => [{ "title" => "Test Req", "body" => "Shall test.", "requirement_type" => "functional", "priority" => "must_have", "asil_level" => "sil_3", "rationale" => "Test" }]
        })
      end

      it "defaults to qm" do
        result = generator.generate(description)
        expect(result[:requirements].first[:asil_level]).to eq("qm")
      end
    end

    context "with mixed case enum values" do
      before do
        allow(mock_llm).to receive(:call).and_return({
          "requirements" => [{ "title" => "Test", "body" => "Shall test.", "requirement_type" => "Non_Functional", "priority" => "Must_Have", "asil_level" => "ASIL_B", "rationale" => "Test" }]
        })
      end

      it "normalizes case correctly" do
        result = generator.generate(description)
        req = result[:requirements].first
        expect(req[:requirement_type]).to eq("non_functional")
        expect(req[:priority]).to eq("must_have")
        expect(req[:asil_level]).to eq("asil_b")
      end
    end

    context "with blank title in a requirement" do
      before do
        allow(mock_llm).to receive(:call).and_return({
          "requirements" => [
            { "title" => "", "body" => "Shall test.", "requirement_type" => "functional", "priority" => "should_have", "asil_level" => "qm", "rationale" => "Test" },
            { "title" => "Valid Req", "body" => "Shall be valid.", "requirement_type" => "functional", "priority" => "should_have", "asil_level" => "qm", "rationale" => "Valid" }
          ]
        })
      end

      it "filters out requirements with blank titles" do
        result = generator.generate(description)
        expect(result[:requirements].length).to eq(1)
        expect(result[:requirements].first[:title]).to eq("Valid Req")
      end
    end

    context "with missing body" do
      before do
        allow(mock_llm).to receive(:call).and_return({
          "requirements" => [{ "title" => "Test Req", "body" => "", "requirement_type" => "functional", "priority" => "should_have", "asil_level" => "qm", "rationale" => "Test" }]
        })
      end

      it "falls back to title as body" do
        result = generator.generate(description)
        expect(result[:requirements].first[:body]).to eq("Test Req")
      end
    end

    context "with nil body" do
      before do
        allow(mock_llm).to receive(:call).and_return({
          "requirements" => [{ "title" => "Test Req", "body" => nil, "requirement_type" => "functional", "priority" => "should_have", "asil_level" => "qm", "rationale" => "Test" }]
        })
      end

      it "falls back to title as body" do
        result = generator.generate(description)
        expect(result[:requirements].first[:body]).to eq("Test Req")
      end
    end

    context "with missing rationale" do
      before do
        allow(mock_llm).to receive(:call).and_return({
          "requirements" => [{ "title" => "Test Req", "body" => "Shall test.", "requirement_type" => "functional", "priority" => "should_have", "asil_level" => "qm" }]
        })
      end

      it "provides default rationale" do
        result = generator.generate(description)
        expect(result[:requirements].first[:rationale]).to eq("Generated from natural language description.")
      end
    end

    context "with more than MAX_REQUIREMENTS results" do
      before do
        reqs = (1..15).map do |i|
          { "title" => "Req #{i}", "body" => "Shall do #{i}.", "requirement_type" => "functional", "priority" => "should_have", "asil_level" => "qm", "rationale" => "Test #{i}" }
        end
        allow(mock_llm).to receive(:call).and_return({ "requirements" => reqs })
      end

      it "caps at MAX_REQUIREMENTS" do
        result = generator.generate(description)
        expect(result[:requirements].length).to eq(RequirementGenerator::MAX_REQUIREMENTS)
      end

      it "keeps the first MAX_REQUIREMENTS items" do
        result = generator.generate(description)
        expect(result[:requirements].first[:title]).to eq("Req 1")
        expect(result[:requirements].last[:title]).to eq("Req 10")
      end
    end

    context "with plain text LLM response" do
      before do
        allow(mock_llm).to receive(:call).and_return({ "text" => "I cannot generate requirements from this." })
      end

      it "returns empty requirements" do
        result = generator.generate(description)
        expect(result[:requirements]).to eq([])
      end
    end

    context "with empty LLM response" do
      before { allow(mock_llm).to receive(:call).and_return(nil) }

      it "returns empty requirements" do
        result = generator.generate(description)
        expect(result[:requirements]).to eq([])
      end
    end

    context "with no requirements array in response" do
      before do
        allow(mock_llm).to receive(:call).and_return({ "summary" => "Something went wrong" })
      end

      it "returns empty requirements" do
        result = generator.generate(description)
        expect(result[:requirements]).to eq([])
      end
    end

    context "with non-hash entries in requirements array" do
      before do
        allow(mock_llm).to receive(:call).and_return({
          "requirements" => [
            "not a hash",
            { "title" => "Valid Req", "body" => "Shall be valid.", "requirement_type" => "functional", "priority" => "should_have", "asil_level" => "qm", "rationale" => "Valid" }
          ]
        })
      end

      it "filters out non-hash entries" do
        result = generator.generate(description)
        expect(result[:requirements].length).to eq(1)
        expect(result[:requirements].first[:title]).to eq("Valid Req")
      end
    end

    context "when LLM raises an error" do
      before { allow(mock_llm).to receive(:call).and_raise(LlmService::Error, "CLI not found") }

      it "wraps in RequirementGenerator::Error" do
        expect { generator.generate(description) }.to raise_error(
          RequirementGenerator::Error, "Requirement generation failed: CLI not found"
        )
      end
    end

    context "when LLM times out" do
      before { allow(mock_llm).to receive(:call).and_raise(LlmService::TimeoutError, "Command timed out") }

      it "wraps in RequirementGenerator::Error" do
        expect { generator.generate(description) }.to raise_error(
          RequirementGenerator::Error, "Requirement generation failed: Command timed out"
        )
      end
    end

    context "with all valid requirement_types" do
      RequirementGenerator::VALID_REQUIREMENT_TYPES.each do |type|
        it "accepts #{type}" do
          allow(mock_llm).to receive(:call).and_return({
            "requirements" => [{ "title" => "Test", "body" => "Shall test.", "requirement_type" => type, "priority" => "should_have", "asil_level" => "qm", "rationale" => "Test" }]
          })
          result = generator.generate(description)
          expect(result[:requirements].first[:requirement_type]).to eq(type)
        end
      end
    end

    context "with all valid priorities" do
      RequirementGenerator::VALID_PRIORITIES.each do |priority|
        it "accepts #{priority}" do
          allow(mock_llm).to receive(:call).and_return({
            "requirements" => [{ "title" => "Test", "body" => "Shall test.", "requirement_type" => "functional", "priority" => priority, "asil_level" => "qm", "rationale" => "Test" }]
          })
          result = generator.generate(description)
          expect(result[:requirements].first[:priority]).to eq(priority)
        end
      end
    end

    context "with all valid ASIL levels" do
      RequirementGenerator::VALID_ASIL_LEVELS.each do |level|
        it "accepts #{level}" do
          allow(mock_llm).to receive(:call).and_return({
            "requirements" => [{ "title" => "Test", "body" => "Shall test.", "requirement_type" => "functional", "priority" => "should_have", "asil_level" => level, "rationale" => "Test" }]
          })
          result = generator.generate(description)
          expect(result[:requirements].first[:asil_level]).to eq(level)
        end
      end
    end

    context "with whitespace in title" do
      before do
        allow(mock_llm).to receive(:call).and_return({
          "requirements" => [{ "title" => "  Trimmed Title  ", "body" => "Shall test.", "requirement_type" => "functional", "priority" => "should_have", "asil_level" => "qm", "rationale" => "Test" }]
        })
      end

      it "trims whitespace from title" do
        result = generator.generate(description)
        expect(result[:requirements].first[:title]).to eq("Trimmed Title")
      end
    end

    context "with whitespace in body" do
      before do
        allow(mock_llm).to receive(:call).and_return({
          "requirements" => [{ "title" => "Test", "body" => "  Trimmed body.  ", "requirement_type" => "functional", "priority" => "should_have", "asil_level" => "qm", "rationale" => "Test" }]
        })
      end

      it "trims whitespace from body" do
        result = generator.generate(description)
        expect(result[:requirements].first[:body]).to eq("Trimmed body.")
      end
    end
  end

  describe "constants" do
    it "VALID_REQUIREMENT_TYPES matches Requirement enum keys" do
      expect(RequirementGenerator::VALID_REQUIREMENT_TYPES).to match_array(Requirement.requirement_types.keys)
    end

    it "VALID_PRIORITIES matches Requirement enum keys" do
      expect(RequirementGenerator::VALID_PRIORITIES).to match_array(Requirement.priorities.keys)
    end

    it "VALID_ASIL_LEVELS matches Requirement enum keys" do
      expect(RequirementGenerator::VALID_ASIL_LEVELS).to match_array(Requirement.asil_levels.keys)
    end

    it "MAX_REQUIREMENTS is 10" do
      expect(RequirementGenerator::MAX_REQUIREMENTS).to eq(10)
    end

    it "SYSTEM_PROMPT mentions INCOSE" do
      expect(RequirementGenerator::SYSTEM_PROMPT).to include("INCOSE")
    end

    it "SYSTEM_PROMPT mentions shall as obligation keyword" do
      expect(RequirementGenerator::SYSTEM_PROMPT).to include("shall")
    end

    it "SYSTEM_PROMPT mentions all requirement types" do
      RequirementGenerator::VALID_REQUIREMENT_TYPES.each do |type|
        expect(RequirementGenerator::SYSTEM_PROMPT).to include(type)
      end
    end

    it "SYSTEM_PROMPT mentions all ASIL levels" do
      RequirementGenerator::VALID_ASIL_LEVELS.each do |level|
        expect(RequirementGenerator::SYSTEM_PROMPT).to include(level)
      end
    end
  end
end
