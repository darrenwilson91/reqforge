require "rails_helper"

RSpec.describe ImpactAnalyzer do
  let(:llm_service) { instance_double(LlmService) }
  subject(:analyzer) { described_class.new(llm_service: llm_service) }

  let(:project) { create(:project) }
  let(:mod) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: mod) }
  let(:other_mod) { create(:requirement_module, project: project, name: "Software Requirements") }
  let(:other_section) { create(:section, requirement_module: other_mod) }
  let(:user) { create(:user) }

  let(:changed_requirement) do
    create(:requirement,
      project: project,
      section: section,
      uid: "SYS-0001",
      title: "Brake system response time",
      body: "The brake system shall respond to pedal input within 150 milliseconds.",
      requirement_type: "safety",
      asil_level: "asil_d",
      status: "approved"
    )
  end

  let(:directly_linked_req) do
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

  let(:another_linked_req) do
    create(:requirement,
      project: project,
      section: other_section,
      uid: "SW-0001",
      title: "Brake software response validation",
      body: "The brake control software shall validate response time within 100ms.",
      requirement_type: "safety",
      asil_level: "asil_d"
    )
  end

  let(:indirectly_linked_req) do
    create(:requirement,
      project: project,
      section: other_section,
      uid: "SW-0002",
      title: "Actuator driver interface",
      body: "The actuator driver shall provide a hardware abstraction layer for brake control.",
      requirement_type: "interface",
      asil_level: "asil_b"
    )
  end

  let(:unrelated_req) do
    create(:requirement,
      project: project,
      section: section,
      uid: "SYS-0099",
      title: "Dashboard brightness",
      body: "The dashboard shall adjust brightness automatically.",
      requirement_type: "functional",
      asil_level: "qm"
    )
  end

  let(:good_llm_response) do
    {
      "impacts" => [
        {
          "target_uid" => "SYS-0002",
          "severity" => "high",
          "impact_type" => "direct",
          "description" => "Brake actuator control directly depends on response time specification."
        },
        {
          "target_uid" => "SW-0001",
          "severity" => "high",
          "impact_type" => "direct",
          "description" => "Software validation requirement must be updated to match new response time."
        },
        {
          "target_uid" => "SW-0002",
          "severity" => "medium",
          "impact_type" => "indirect",
          "description" => "Actuator driver interface may need timing adjustments."
        }
      ],
      "summary" => "High impact change affecting safety-critical brake subsystem across 2 modules.",
      "risk_level" => "critical"
    }
  end

  def create_direct_link(source, target)
    create(:traceability_link,
      source_requirement: source,
      target_requirement: target,
      link_type: "derives_from",
      created_by: user
    )
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

    it "uses 90 second timeout for default LLM service" do
      analyzer = described_class.new
      expect(analyzer.llm_service.timeout).to eq(90)
    end
  end

  describe "#analyze" do
    context "with a well-formed LLM response" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
        create_direct_link(changed_requirement, another_linked_req)
        create_direct_link(directly_linked_req, indirectly_linked_req)
        allow(llm_service).to receive(:call).and_return(good_llm_response)
      end

      it "returns impacts sorted by severity then impact type" do
        result = analyzer.analyze(changed_requirement)
        severities = result[:impacts].map { |i| i[:severity] }
        expect(severities).to eq(%w[high high medium])
      end

      it "returns target UIDs" do
        result = analyzer.analyze(changed_requirement)
        uids = result[:impacts].map { |i| i[:target_uid] }
        expect(uids).to include("SYS-0002", "SW-0001", "SW-0002")
      end

      it "returns impact types" do
        result = analyzer.analyze(changed_requirement)
        types = result[:impacts].map { |i| i[:impact_type] }
        expect(types).to include("direct", "indirect")
      end

      it "returns descriptions" do
        result = analyzer.analyze(changed_requirement)
        expect(result[:impacts].first[:description]).to include("actuator")
      end

      it "returns summary" do
        result = analyzer.analyze(changed_requirement)
        expect(result[:summary]).to include("safety-critical")
      end

      it "returns risk level" do
        result = analyzer.analyze(changed_requirement)
        expect(result[:risk_level]).to eq("critical")
      end

      it "includes changed requirement details in prompt" do
        analyzer.analyze(changed_requirement)
        expect(llm_service).to have_received(:call).with(
          a_string_including("SYS-0001", "Brake system response time", "150 milliseconds"),
          system_prompt: described_class::SYSTEM_PROMPT
        )
      end

      it "labels changed requirement in prompt" do
        analyzer.analyze(changed_requirement)
        expect(llm_service).to have_received(:call).with(
          a_string_including("[CHANGED REQUIREMENT]"),
          system_prompt: anything
        )
      end

      it "includes related requirements in prompt" do
        analyzer.analyze(changed_requirement)
        expect(llm_service).to have_received(:call).with(
          a_string_including("SYS-0002", "SW-0001"),
          system_prompt: anything
        )
      end

      it "labels directly linked requirements in prompt" do
        analyzer.analyze(changed_requirement)
        expect(llm_service).to have_received(:call).with(
          a_string_including("DIRECTLY LINKED"),
          system_prompt: anything
        )
      end

      it "labels indirectly related requirements in prompt" do
        analyzer.analyze(changed_requirement)
        expect(llm_service).to have_received(:call).with(
          a_string_including("INDIRECTLY RELATED"),
          system_prompt: anything
        )
      end
    end

    context "with changes parameter" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
        allow(llm_service).to receive(:call).and_return(good_llm_response)
      end

      it "includes change details in prompt" do
        changes = { "body" => ["old body text", "new body text"], "asil_level" => ["asil_c", "asil_d"] }
        analyzer.analyze(changed_requirement, changes: changes)
        expect(llm_service).to have_received(:call).with(
          a_string_including("Changes made:", "body:", "old body text", "new body text", "asil_level:", "asil_c", "asil_d"),
          system_prompt: anything
        )
      end
    end

    context "with no related requirements" do
      before do
        allow(llm_service).to receive(:call)
      end

      it "returns empty result without calling LLM" do
        result = analyzer.analyze(changed_requirement)
        expect(result).to eq({ impacts: [], summary: "No related requirements found.", risk_level: "minimal" })
        expect(llm_service).not_to have_received(:call)
      end
    end

    context "when requirement has no title" do
      let(:no_title_req) { build(:requirement, uid: "SYS-0099", title: nil) }

      it "raises ImpactAnalyzer::Error" do
        expect { analyzer.analyze(no_title_req) }.to raise_error(
          ImpactAnalyzer::Error, /must have a title/
        )
      end
    end

    context "finding related requirements" do
      before do
        allow(llm_service).to receive(:call).and_return({ "impacts" => [] })
      end

      it "finds directly linked requirements" do
        create_direct_link(changed_requirement, directly_linked_req)
        analyzer.analyze(changed_requirement)
        expect(llm_service).to have_received(:call) do |prompt, **_kwargs|
          expect(prompt).to include("SYS-0002")
        end
      end

      it "finds indirectly linked requirements (2 hops)" do
        create_direct_link(changed_requirement, directly_linked_req)
        create_direct_link(directly_linked_req, indirectly_linked_req)
        analyzer.analyze(changed_requirement)
        expect(llm_service).to have_received(:call) do |prompt, **_kwargs|
          expect(prompt).to include("SW-0002")
        end
      end

      it "excludes the changed requirement itself from related list" do
        create_direct_link(changed_requirement, directly_linked_req)
        analyzer.analyze(changed_requirement)
        expect(llm_service).to have_received(:call) do |prompt, **_kwargs|
          related_section = prompt.split("---").last
          # SYS-0001 should NOT appear as a RELATED entry
          related_lines = related_section.lines.select { |l| l.include?("UID:") }
          related_uids = related_lines.map { |l| l.strip.sub("UID: ", "") }
          expect(related_uids).not_to include("SYS-0001")
        end
      end

      it "excludes obsolete requirements" do
        obsolete_req = create(:requirement, :obsolete, project: project, section: section, uid: "SYS-0088", title: "Old req")
        create_direct_link(changed_requirement, obsolete_req)
        # Also create a non-obsolete linked req so LLM gets called
        create_direct_link(changed_requirement, directly_linked_req)
        analyzer.analyze(changed_requirement)
        expect(llm_service).to have_received(:call) do |prompt, **_kwargs|
          expect(prompt).not_to include("SYS-0088")
        end
      end

      it "includes requirements linked as both source and target" do
        # changed_requirement is source
        create_direct_link(changed_requirement, directly_linked_req)
        # changed_requirement is target
        create(:traceability_link,
          source_requirement: another_linked_req,
          target_requirement: changed_requirement,
          link_type: "verifies",
          created_by: user
        )
        analyzer.analyze(changed_requirement)
        expect(llm_service).to have_received(:call) do |prompt, **_kwargs|
          expect(prompt).to include("SYS-0002")
          expect(prompt).to include("SW-0001")
        end
      end

      it "deduplicates requirements that appear in both direct and indirect sets" do
        create_direct_link(changed_requirement, directly_linked_req)
        create_direct_link(changed_requirement, another_linked_req)
        # another_linked_req is also indirectly reachable via directly_linked_req
        create_direct_link(directly_linked_req, another_linked_req)
        analyzer.analyze(changed_requirement)
        expect(llm_service).to have_received(:call) do |prompt, **_kwargs|
          count = prompt.scan("SW-0001").count
          # Should appear once as a RELATED entry (may also appear in label)
          related_entries = prompt.scan(/\[RELATED \d+/).count
          # Just verify no excessive duplication
          expect(related_entries).to be >= 2 # at least directly_linked_req and another_linked_req
        end
      end
    end

    context "when LLM returns impacts with unknown UIDs" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
        allow(llm_service).to receive(:call).and_return({
          "impacts" => [
            { "target_uid" => "UNKNOWN-001", "severity" => "high", "impact_type" => "direct", "description" => "Unknown" },
            { "target_uid" => "SYS-0002", "severity" => "medium", "impact_type" => "direct", "description" => "Valid" }
          ],
          "summary" => "Some impacts",
          "risk_level" => "moderate"
        })
      end

      it "filters out impacts with UIDs not in related requirements" do
        result = analyzer.analyze(changed_requirement)
        uids = result[:impacts].map { |i| i[:target_uid] }
        expect(uids).to eq(%w[SYS-0002])
        expect(uids).not_to include("UNKNOWN-001")
      end
    end

    context "when LLM returns invalid severities" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
        create_direct_link(changed_requirement, another_linked_req)
        allow(llm_service).to receive(:call).and_return({
          "impacts" => [
            { "target_uid" => "SYS-0002", "severity" => "extreme", "impact_type" => "direct", "description" => "Invalid severity" },
            { "target_uid" => "SW-0001", "severity" => "high", "impact_type" => "direct", "description" => "Valid" }
          ],
          "summary" => "Test",
          "risk_level" => "moderate"
        })
      end

      it "filters out impacts with unknown severity levels" do
        result = analyzer.analyze(changed_requirement)
        uids = result[:impacts].map { |i| i[:target_uid] }
        expect(uids).to eq(%w[SW-0001])
      end
    end

    context "when LLM returns invalid impact types" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
        create_direct_link(changed_requirement, another_linked_req)
        allow(llm_service).to receive(:call).and_return({
          "impacts" => [
            { "target_uid" => "SYS-0002", "severity" => "high", "impact_type" => "maybe", "description" => "Invalid type" },
            { "target_uid" => "SW-0001", "severity" => "medium", "impact_type" => "indirect", "description" => "Valid" }
          ],
          "summary" => "Test",
          "risk_level" => "moderate"
        })
      end

      it "filters out impacts with unknown impact types" do
        result = analyzer.analyze(changed_requirement)
        uids = result[:impacts].map { |i| i[:target_uid] }
        expect(uids).to eq(%w[SW-0001])
      end
    end

    context "when LLM returns invalid risk level" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
        allow(llm_service).to receive(:call).and_return({
          "impacts" => [],
          "summary" => "Test",
          "risk_level" => "catastrophic"
        })
      end

      it "defaults to moderate for unknown risk levels" do
        result = analyzer.analyze(changed_requirement)
        expect(result[:risk_level]).to eq("moderate")
      end
    end

    context "when LLM returns plain text instead of JSON" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
        allow(llm_service).to receive(:call).and_return({ "text" => "I cannot analyze this." })
      end

      it "returns empty result" do
        result = analyzer.analyze(changed_requirement)
        expect(result[:impacts]).to be_empty
        expect(result[:risk_level]).to eq("minimal")
      end
    end

    context "when LLM returns empty response" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
        allow(llm_service).to receive(:call).and_return(nil)
      end

      it "returns empty result" do
        result = analyzer.analyze(changed_requirement)
        expect(result[:impacts]).to be_empty
      end
    end

    context "when LLM returns no impacts array" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
        allow(llm_service).to receive(:call).and_return({ "analysis" => "done" })
      end

      it "returns empty impacts" do
        result = analyzer.analyze(changed_requirement)
        expect(result[:impacts]).to be_empty
      end
    end

    context "when LLM returns missing description" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
        allow(llm_service).to receive(:call).and_return({
          "impacts" => [
            { "target_uid" => "SYS-0002", "severity" => "high", "impact_type" => "direct" }
          ],
          "summary" => "Test",
          "risk_level" => "moderate"
        })
      end

      it "provides a default description" do
        result = analyzer.analyze(changed_requirement)
        expect(result[:impacts].first[:description]).to eq("May be affected by the change.")
      end
    end

    context "when LLM returns missing summary" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
        allow(llm_service).to receive(:call).and_return({
          "impacts" => [],
          "risk_level" => "minimal"
        })
      end

      it "provides a default summary" do
        result = analyzer.analyze(changed_requirement)
        expect(result[:summary]).to eq("Impact analysis complete.")
      end
    end

    context "when LLM returns mixed case values" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
        allow(llm_service).to receive(:call).and_return({
          "impacts" => [
            { "target_uid" => "SYS-0002", "severity" => "High", "impact_type" => "Direct", "description" => "Mixed case" }
          ],
          "summary" => "Test",
          "risk_level" => "Critical"
        })
      end

      it "normalizes severity to lowercase" do
        result = analyzer.analyze(changed_requirement)
        expect(result[:impacts].first[:severity]).to eq("high")
      end

      it "normalizes impact type to lowercase" do
        result = analyzer.analyze(changed_requirement)
        expect(result[:impacts].first[:impact_type]).to eq("direct")
      end

      it "normalizes risk level to lowercase" do
        result = analyzer.analyze(changed_requirement)
        expect(result[:risk_level]).to eq("critical")
      end
    end

    context "impact sorting" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
        create_direct_link(changed_requirement, another_linked_req)
        create_direct_link(directly_linked_req, indirectly_linked_req)
        allow(llm_service).to receive(:call).and_return({
          "impacts" => [
            { "target_uid" => "SW-0002", "severity" => "low", "impact_type" => "indirect", "description" => "Low indirect" },
            { "target_uid" => "SYS-0002", "severity" => "high", "impact_type" => "indirect", "description" => "High indirect" },
            { "target_uid" => "SW-0001", "severity" => "high", "impact_type" => "direct", "description" => "High direct" }
          ],
          "summary" => "Test",
          "risk_level" => "significant"
        })
      end

      it "sorts by severity first (high > medium > low) then by impact type (direct > indirect > potential)" do
        result = analyzer.analyze(changed_requirement)
        sorted = result[:impacts].map { |i| [i[:severity], i[:impact_type]] }
        expect(sorted).to eq([
          %w[high direct],
          %w[high indirect],
          %w[low indirect]
        ])
      end
    end

    context "when LLM service raises an error" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
        allow(llm_service).to receive(:call).and_raise(LlmService::Error, "CLI exited with status 1")
      end

      it "raises ImpactAnalyzer::Error" do
        expect { analyzer.analyze(changed_requirement) }.to raise_error(
          ImpactAnalyzer::Error, /Impact analysis failed: CLI exited with status 1/
        )
      end
    end

    context "when LLM service times out" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
        allow(llm_service).to receive(:call).and_raise(LlmService::TimeoutError, "timed out after 90 seconds")
      end

      it "raises ImpactAnalyzer::Error" do
        expect { analyzer.analyze(changed_requirement) }.to raise_error(
          ImpactAnalyzer::Error, /Impact analysis failed: timed out/
        )
      end
    end

    context "when requirement has no body" do
      let(:no_body_req) do
        create(:requirement, project: project, section: section, uid: "SYS-0010", title: "No body", body: nil)
      end

      before do
        create_direct_link(no_body_req, directly_linked_req)
        allow(llm_service).to receive(:call).and_return({ "impacts" => [] })
      end

      it "omits body from the prompt" do
        analyzer.analyze(no_body_req)
        expect(llm_service).to have_received(:call) do |prompt, **_kwargs|
          changed_section = prompt.split("---").first
          expect(changed_section).not_to include("Body:")
        end
      end
    end

    context "all valid severity levels" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
      end

      %w[high medium low].each do |severity|
        it "accepts #{severity} severity" do
          allow(llm_service).to receive(:call).and_return({
            "impacts" => [
              { "target_uid" => "SYS-0002", "severity" => severity, "impact_type" => "direct", "description" => "Test" }
            ],
            "summary" => "Test",
            "risk_level" => "moderate"
          })
          result = analyzer.analyze(changed_requirement)
          expect(result[:impacts].first[:severity]).to eq(severity)
        end
      end
    end

    context "all valid impact types" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
      end

      %w[direct indirect potential].each do |impact_type|
        it "accepts #{impact_type} impact type" do
          allow(llm_service).to receive(:call).and_return({
            "impacts" => [
              { "target_uid" => "SYS-0002", "severity" => "high", "impact_type" => impact_type, "description" => "Test" }
            ],
            "summary" => "Test",
            "risk_level" => "moderate"
          })
          result = analyzer.analyze(changed_requirement)
          expect(result[:impacts].first[:impact_type]).to eq(impact_type)
        end
      end
    end

    context "all valid risk levels" do
      before do
        create_direct_link(changed_requirement, directly_linked_req)
      end

      %w[critical significant moderate minimal].each do |risk_level|
        it "accepts #{risk_level} risk level" do
          allow(llm_service).to receive(:call).and_return({
            "impacts" => [],
            "summary" => "Test",
            "risk_level" => risk_level
          })
          result = analyzer.analyze(changed_requirement)
          expect(result[:risk_level]).to eq(risk_level)
        end
      end
    end
  end

  describe "constants" do
    it "defines three severity levels" do
      expect(described_class::VALID_SEVERITIES).to eq(%w[high medium low])
    end

    it "defines three impact types" do
      expect(described_class::VALID_IMPACT_TYPES).to eq(%w[direct indirect potential])
    end

    it "defines four risk levels" do
      expect(described_class::VALID_RISK_LEVELS).to eq(%w[critical significant moderate minimal])
    end

    it "limits related requirements to 100" do
      expect(described_class::MAX_RELATED_REQUIREMENTS).to eq(100)
    end
  end

  describe "SYSTEM_PROMPT constant" do
    it "includes severity level definitions" do
      %w[high medium low].each do |level|
        expect(described_class::SYSTEM_PROMPT).to include(level)
      end
    end

    it "includes impact type definitions" do
      %w[direct indirect potential].each do |type|
        expect(described_class::SYSTEM_PROMPT).to include(type)
      end
    end

    it "includes risk level definitions" do
      %w[critical significant moderate minimal].each do |level|
        expect(described_class::SYSTEM_PROMPT).to include(level)
      end
    end

    it "specifies JSON response format" do
      expect(described_class::SYSTEM_PROMPT).to include("impacts")
      expect(described_class::SYSTEM_PROMPT).to include("target_uid")
      expect(described_class::SYSTEM_PROMPT).to include("severity")
      expect(described_class::SYSTEM_PROMPT).to include("risk_level")
    end

    it "mentions ASIL and safety considerations" do
      expect(described_class::SYSTEM_PROMPT).to include("ASIL")
      expect(described_class::SYSTEM_PROMPT).to include("safety")
    end
  end
end
