require "rails_helper"

RSpec.describe QualityAnalyzer do
  let(:llm_service) { instance_double(LlmService) }
  subject(:analyzer) { described_class.new(llm_service: llm_service) }

  let(:requirement) do
    build(:requirement,
      uid: "SYS-0001",
      title: "System response time",
      body: "The system shall respond to user input within 200 milliseconds.",
      requirement_type: "functional",
      asil_level: "qm"
    )
  end

  let(:good_llm_response) do
    {
      "overall_score" => 85,
      "checks" => [
        {
          "rule" => "ambiguity",
          "passed" => true,
          "score" => 90,
          "issues" => [],
          "suggestions" => []
        },
        {
          "rule" => "completeness",
          "passed" => true,
          "score" => 80,
          "issues" => [],
          "suggestions" => ["Consider specifying the measurement conditions"]
        },
        {
          "rule" => "singularity",
          "passed" => true,
          "score" => 100,
          "issues" => [],
          "suggestions" => []
        },
        {
          "rule" => "correctness",
          "passed" => true,
          "score" => 90,
          "issues" => [],
          "suggestions" => []
        },
        {
          "rule" => "verifiability",
          "passed" => true,
          "score" => 85,
          "issues" => [],
          "suggestions" => ["Specify the test method for response time measurement"]
        },
        {
          "rule" => "conformance",
          "passed" => true,
          "score" => 80,
          "issues" => [],
          "suggestions" => []
        }
      ],
      "summary" => "Good quality requirement with measurable criteria."
    }
  end

  describe "#initialize" do
    it "accepts a custom LLM service" do
      custom = LlmService.new(timeout: 120)
      analyzer = described_class.new(llm_service: custom)
      expect(analyzer.llm_service).to eq(custom)
    end

    it "creates a default LLM service if none provided" do
      analyzer = described_class.new
      expect(analyzer.llm_service).to be_a(LlmService)
    end

    it "uses 60 second timeout for default LLM service" do
      analyzer = described_class.new
      expect(analyzer.llm_service.timeout).to eq(60)
    end
  end

  describe "#analyze" do
    context "with a well-formed LLM response" do
      before do
        allow(llm_service).to receive(:call).and_return(good_llm_response)
      end

      it "returns the overall score" do
        result = analyzer.analyze(requirement)
        expect(result[:overall_score]).to eq(85)
      end

      it "returns checks for all six INCOSE rules" do
        result = analyzer.analyze(requirement)
        rules = result[:checks].map { |c| c[:rule] }
        expect(rules).to eq(%w[ambiguity completeness singularity correctness verifiability conformance])
      end

      it "preserves pass/fail status per check" do
        result = analyzer.analyze(requirement)
        expect(result[:checks].all? { |c| c[:passed] == true }).to be true
      end

      it "preserves scores per check" do
        result = analyzer.analyze(requirement)
        scores = result[:checks].map { |c| c[:score] }
        expect(scores).to eq([90, 80, 100, 90, 85, 80])
      end

      it "preserves suggestions" do
        result = analyzer.analyze(requirement)
        completeness = result[:checks].find { |c| c[:rule] == "completeness" }
        expect(completeness[:suggestions]).to include("Consider specifying the measurement conditions")
      end

      it "returns the summary" do
        result = analyzer.analyze(requirement)
        expect(result[:summary]).to eq("Good quality requirement with measurable criteria.")
      end

      it "passes the requirement details in the prompt" do
        analyzer.analyze(requirement)
        expect(llm_service).to have_received(:call).with(
          a_string_including("SYS-0001", "System response time", "200 milliseconds"),
          system_prompt: described_class::SYSTEM_PROMPT
        )
      end

      it "includes requirement type in prompt" do
        analyzer.analyze(requirement)
        expect(llm_service).to have_received(:call).with(
          a_string_including("Functional"),
          system_prompt: anything
        )
      end

      it "includes ASIL level in prompt" do
        analyzer.analyze(requirement)
        expect(llm_service).to have_received(:call).with(
          a_string_including("QM"),
          system_prompt: anything
        )
      end
    end

    context "with a requirement that has issues" do
      let(:issue_response) do
        {
          "overall_score" => 35,
          "checks" => [
            {
              "rule" => "ambiguity",
              "passed" => false,
              "score" => 20,
              "issues" => ["Vague term: 'appropriate'", "Vague term: 'adequate'"],
              "suggestions" => ["Replace 'appropriate' with a specific measurable value", "Define what 'adequate' means quantitatively"]
            },
            {
              "rule" => "completeness",
              "passed" => false,
              "score" => 40,
              "issues" => ["Missing performance criteria"],
              "suggestions" => ["Add specific timing requirements"]
            },
            {
              "rule" => "singularity",
              "passed" => false,
              "score" => 30,
              "issues" => ["Compound requirement using 'and' to combine behaviors"],
              "suggestions" => ["Split into two separate requirements"]
            },
            {
              "rule" => "correctness",
              "passed" => true,
              "score" => 80,
              "issues" => [],
              "suggestions" => []
            },
            {
              "rule" => "verifiability",
              "passed" => false,
              "score" => 10,
              "issues" => ["No measurable criteria specified"],
              "suggestions" => ["Add numeric thresholds"]
            },
            {
              "rule" => "conformance",
              "passed" => false,
              "score" => 30,
              "issues" => ["Uses 'should' instead of 'shall'"],
              "suggestions" => ["Replace 'should' with 'shall'"]
            }
          ],
          "summary" => "Poor quality requirement with multiple issues."
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(issue_response)
      end

      it "returns low overall score" do
        result = analyzer.analyze(requirement)
        expect(result[:overall_score]).to eq(35)
      end

      it "marks failing checks correctly" do
        result = analyzer.analyze(requirement)
        failing = result[:checks].select { |c| !c[:passed] }
        expect(failing.length).to eq(5)
      end

      it "includes multiple issues per check" do
        result = analyzer.analyze(requirement)
        ambiguity = result[:checks].find { |c| c[:rule] == "ambiguity" }
        expect(ambiguity[:issues].length).to eq(2)
      end

      it "includes issue descriptions" do
        result = analyzer.analyze(requirement)
        ambiguity = result[:checks].find { |c| c[:rule] == "ambiguity" }
        expect(ambiguity[:issues]).to include("Vague term: 'appropriate'")
      end

      it "includes suggestions for failing checks" do
        result = analyzer.analyze(requirement)
        conformance = result[:checks].find { |c| c[:rule] == "conformance" }
        expect(conformance[:suggestions]).to include("Replace 'should' with 'shall'")
      end
    end

    context "when requirement has no body" do
      let(:requirement_no_body) do
        build(:requirement, uid: "SYS-0002", title: "Login requirement", body: nil)
      end

      before do
        allow(llm_service).to receive(:call).and_return(good_llm_response)
      end

      it "omits body from the prompt" do
        analyzer.analyze(requirement_no_body)
        expect(llm_service).to have_received(:call) do |prompt, **_kwargs|
          expect(prompt).not_to include("Body:")
        end
      end

      it "includes the title in the prompt" do
        analyzer.analyze(requirement_no_body)
        expect(llm_service).to have_received(:call).with(
          a_string_including("Login requirement"),
          system_prompt: anything
        )
      end
    end

    context "when requirement has no title" do
      let(:requirement_no_title) do
        build(:requirement, uid: "SYS-0003", title: nil)
      end

      it "raises QualityAnalyzer::Error" do
        expect { analyzer.analyze(requirement_no_title) }.to raise_error(
          QualityAnalyzer::Error, /must have a title/
        )
      end
    end

    context "when LLM returns partial checks" do
      let(:partial_response) do
        {
          "overall_score" => 60,
          "checks" => [
            { "rule" => "ambiguity", "passed" => true, "score" => 80, "issues" => [], "suggestions" => [] },
            { "rule" => "conformance", "passed" => false, "score" => 40, "issues" => ["Missing 'shall'"], "suggestions" => [] }
          ],
          "summary" => "Partial analysis."
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(partial_response)
      end

      it "fills in missing rules with defaults" do
        result = analyzer.analyze(requirement)
        rules = result[:checks].map { |c| c[:rule] }
        expect(rules).to eq(%w[ambiguity completeness singularity correctness verifiability conformance])
      end

      it "gives missing rules a passing score of 100" do
        result = analyzer.analyze(requirement)
        completeness = result[:checks].find { |c| c[:rule] == "completeness" }
        expect(completeness[:score]).to eq(100)
        expect(completeness[:passed]).to be true
      end

      it "preserves explicitly returned checks" do
        result = analyzer.analyze(requirement)
        conformance = result[:checks].find { |c| c[:rule] == "conformance" }
        expect(conformance[:passed]).to be false
        expect(conformance[:score]).to eq(40)
      end
    end

    context "when LLM returns plain text instead of JSON" do
      before do
        allow(llm_service).to receive(:call).and_return({ "text" => "I cannot analyze this requirement." })
      end

      it "returns an error response" do
        result = analyzer.analyze(requirement)
        expect(result[:overall_score]).to eq(0)
      end

      it "sets error message in summary" do
        result = analyzer.analyze(requirement)
        expect(result[:summary]).to include("non-structured response")
      end

      it "marks all checks as failed" do
        result = analyzer.analyze(requirement)
        expect(result[:checks].all? { |c| c[:passed] == false }).to be true
      end
    end

    context "when LLM returns empty response" do
      before do
        allow(llm_service).to receive(:call).and_return(nil)
      end

      it "returns an error response" do
        result = analyzer.analyze(requirement)
        expect(result[:overall_score]).to eq(0)
        expect(result[:summary]).to include("Empty response")
      end
    end

    context "when LLM service raises an error" do
      before do
        allow(llm_service).to receive(:call).and_raise(LlmService::Error, "CLI exited with status 1")
      end

      it "raises QualityAnalyzer::Error" do
        expect { analyzer.analyze(requirement) }.to raise_error(
          QualityAnalyzer::Error, /Quality analysis failed: CLI exited with status 1/
        )
      end
    end

    context "when LLM service times out" do
      before do
        allow(llm_service).to receive(:call).and_raise(LlmService::TimeoutError, "timed out after 60 seconds")
      end

      it "raises QualityAnalyzer::Error" do
        expect { analyzer.analyze(requirement) }.to raise_error(
          QualityAnalyzer::Error, /Quality analysis failed: timed out/
        )
      end
    end

    context "when LLM returns scores out of range" do
      let(:out_of_range_response) do
        {
          "overall_score" => 150,
          "checks" => [
            { "rule" => "ambiguity", "passed" => true, "score" => -10, "issues" => [], "suggestions" => [] },
            { "rule" => "completeness", "passed" => true, "score" => 200, "issues" => [], "suggestions" => [] }
          ],
          "summary" => "Scores out of range."
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(out_of_range_response)
      end

      it "clamps overall score to 0-100" do
        result = analyzer.analyze(requirement)
        expect(result[:overall_score]).to eq(100)
      end

      it "clamps negative check scores to 0" do
        result = analyzer.analyze(requirement)
        ambiguity = result[:checks].find { |c| c[:rule] == "ambiguity" }
        expect(ambiguity[:score]).to eq(0)
      end

      it "clamps high check scores to 100" do
        result = analyzer.analyze(requirement)
        completeness = result[:checks].find { |c| c[:rule] == "completeness" }
        expect(completeness[:score]).to eq(100)
      end
    end

    context "when LLM returns checks with unknown rules" do
      let(:unknown_rule_response) do
        {
          "overall_score" => 70,
          "checks" => [
            { "rule" => "ambiguity", "passed" => true, "score" => 80, "issues" => [], "suggestions" => [] },
            { "rule" => "made_up_rule", "passed" => false, "score" => 50, "issues" => ["Fake"], "suggestions" => [] },
            { "rule" => "conformance", "passed" => true, "score" => 90, "issues" => [], "suggestions" => [] }
          ],
          "summary" => "Analysis with unknown rules."
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(unknown_rule_response)
      end

      it "filters out unknown rules" do
        result = analyzer.analyze(requirement)
        rules = result[:checks].map { |c| c[:rule] }
        expect(rules).not_to include("made_up_rule")
      end

      it "still includes all six standard rules" do
        result = analyzer.analyze(requirement)
        rules = result[:checks].map { |c| c[:rule] }
        expect(rules).to eq(%w[ambiguity completeness singularity correctness verifiability conformance])
      end
    end

    context "when LLM returns no checks array" do
      let(:no_checks_response) do
        {
          "overall_score" => 50,
          "summary" => "Could not determine individual checks."
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(no_checks_response)
      end

      it "returns default checks for all rules" do
        result = analyzer.analyze(requirement)
        expect(result[:checks].length).to eq(6)
      end

      it "marks default checks as unable to analyze" do
        result = analyzer.analyze(requirement)
        result[:checks].each do |check|
          expect(check[:issues]).to include("Unable to analyze")
        end
      end
    end

    context "when LLM returns no summary" do
      let(:no_summary_response) do
        {
          "overall_score" => 75,
          "checks" => good_llm_response["checks"]
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(no_summary_response)
      end

      it "provides default summary" do
        result = analyzer.analyze(requirement)
        expect(result[:summary]).to eq("Analysis complete.")
      end
    end

    context "with case-insensitive rule names" do
      let(:mixed_case_response) do
        {
          "overall_score" => 80,
          "checks" => [
            { "rule" => "Ambiguity", "passed" => true, "score" => 80, "issues" => [], "suggestions" => [] },
            { "rule" => "COMPLETENESS", "passed" => true, "score" => 80, "issues" => [], "suggestions" => [] }
          ],
          "summary" => "Mixed case rules."
        }
      end

      before do
        allow(llm_service).to receive(:call).and_return(mixed_case_response)
      end

      it "normalizes rule names to lowercase" do
        result = analyzer.analyze(requirement)
        ambiguity = result[:checks].find { |c| c[:rule] == "ambiguity" }
        expect(ambiguity[:score]).to eq(80)
      end
    end
  end

  describe "RULES constant" do
    it "defines all six INCOSE quality rules" do
      expect(described_class::RULES).to eq(%w[ambiguity completeness singularity correctness verifiability conformance])
    end
  end

  describe "SYSTEM_PROMPT constant" do
    it "includes all six rule names" do
      %w[ambiguity completeness singularity correctness verifiability conformance].each do |rule|
        expect(described_class::SYSTEM_PROMPT).to include(rule)
      end
    end

    it "includes INCOSE reference" do
      expect(described_class::SYSTEM_PROMPT).to include("INCOSE")
    end

    it "specifies JSON response format" do
      expect(described_class::SYSTEM_PROMPT).to include("overall_score")
      expect(described_class::SYSTEM_PROMPT).to include("checks")
    end
  end
end
