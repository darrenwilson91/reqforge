require 'rails_helper'

RSpec.describe ComplianceTemplate, type: :model do
  describe "factory" do
    it "has a valid default factory" do
      expect(build(:compliance_template)).to be_valid
    end

    it "has a valid iso_26262 factory" do
      expect(build(:compliance_template, :iso_26262)).to be_valid
    end

    it "has a valid aspice factory" do
      expect(build(:compliance_template, :aspice)).to be_valid
    end

    it "has a valid inactive factory" do
      template = build(:compliance_template, :inactive)
      expect(template).to be_valid
      expect(template.active).to be false
    end
  end

  describe "validations" do
    subject { build(:compliance_template) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_presence_of(:standard) }
    it { is_expected.to validate_presence_of(:template_data) }

    it "rejects duplicate names" do
      create(:compliance_template, name: "Unique Template")
      duplicate = build(:compliance_template, name: "Unique Template")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end
  end

  describe "defaults" do
    it "defaults active to true" do
      template = described_class.new
      expect(template.active).to be true
    end

    it "defaults template_data to empty hash" do
      template = described_class.new
      expect(template.template_data).to eq({})
    end
  end

  describe "scopes" do
    let!(:active_iso) { create(:compliance_template, :iso_26262) }
    let!(:active_aspice) { create(:compliance_template, :aspice) }
    let!(:inactive) { create(:compliance_template, :inactive, name: "Old Template", standard: "legacy") }

    describe ".active" do
      it "returns only active templates" do
        expect(described_class.active).to contain_exactly(active_iso, active_aspice)
      end
    end

    describe ".for_standard" do
      it "filters by standard" do
        expect(described_class.for_standard("iso_26262")).to contain_exactly(active_iso)
        expect(described_class.for_standard("aspice")).to contain_exactly(active_aspice)
      end
    end
  end

  describe "constants" do
    it "defines STANDARDS" do
      expect(ComplianceTemplate::STANDARDS).to eq(%w[iso_26262 aspice])
    end
  end

  describe "#apply_to_project!" do
    let(:organization) { create(:organization) }
    let(:project) { create(:project, organization: organization) }
    let(:template) { create(:compliance_template) }

    it "creates modules from template data" do
      template.apply_to_project!(project)
      expect(project.requirement_modules.count).to eq(2)
      expect(project.requirement_modules.pluck(:name)).to contain_exactly("Module A", "Module B")
    end

    it "creates sections within modules" do
      template.apply_to_project!(project)
      mod_a = project.requirement_modules.find_by(name: "Module A")
      expect(mod_a.sections.count).to eq(2)
      expect(mod_a.sections.pluck(:name)).to contain_exactly("Section A1", "Section A2")
    end

    it "sets module positions in order" do
      template.apply_to_project!(project)
      modules = project.requirement_modules.order(:position)
      expect(modules.map(&:name)).to eq(["Module A", "Module B"])
      expect(modules.map(&:position)).to eq([1, 2])
    end

    it "sets section positions in order" do
      template.apply_to_project!(project)
      mod_a = project.requirement_modules.find_by(name: "Module A")
      sections = mod_a.sections.order(:position)
      expect(sections.map(&:name)).to eq(["Section A1", "Section A2"])
      expect(sections.map(&:position)).to eq([1, 2])
    end

    it "sets attribute_schema on the project" do
      template.apply_to_project!(project)
      project.reload
      expect(project.attribute_schema).to be_present
      expect(project.attribute_schema.first["name"]).to eq("Test Attr")
    end

    it "returns a module_map keyed by template key" do
      result = template.apply_to_project!(project)
      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly("mod_a", "mod_b")
      expect(result["mod_a"]).to be_a(RequirementModule)
      expect(result["mod_a"].name).to eq("Module A")
    end

    context "with ISO 26262 template" do
      let(:iso_template) { create(:compliance_template, :iso_26262) }

      it "creates 7 V-model phase modules" do
        iso_template.apply_to_project!(project)
        expect(project.requirement_modules.count).to eq(7)
      end

      it "creates all expected sections" do
        iso_template.apply_to_project!(project)
        total_sections = project.requirement_modules.sum { |m| m.sections.count }
        expect(total_sections).to eq(18) # 3+4+3+2+2+2+2
      end

      it "sets ISO 26262 attribute schema with 4 attributes" do
        iso_template.apply_to_project!(project)
        project.reload
        expect(project.attribute_schema.length).to eq(4)
        attr_names = project.attribute_schema.map { |a| a["name"] }
        expect(attr_names).to include("Safety Goal", "ASIL Allocation", "Verification Method", "Compliance Reference")
      end
    end

    context "with ASPICE template" do
      let(:aspice_template) { create(:compliance_template, :aspice) }

      it "creates 9 process area modules" do
        aspice_template.apply_to_project!(project)
        expect(project.requirement_modules.count).to eq(9)
      end

      it "creates all expected sections" do
        aspice_template.apply_to_project!(project)
        total_sections = project.requirement_modules.sum { |m| m.sections.count }
        # SWE.1: 4, SWE.2: 4, SWE.3: 3, SWE.4: 3, SWE.5: 3, SWE.6: 3, SUP.7: 2, SUP.9: 2, SUP.10: 2 = 26
        expect(total_sections).to eq(26)
      end

      it "sets ASPICE attribute schema with 4 attributes" do
        aspice_template.apply_to_project!(project)
        project.reload
        expect(project.attribute_schema.length).to eq(4)
        attr_names = project.attribute_schema.map { |a| a["name"] }
        expect(attr_names).to include("Process Area", "Capability Level", "Work Product ID", "Compliance Reference")
      end
    end

    context "with no attribute_schema in template" do
      let(:bare_template) do
        create(:compliance_template, template_data: {
          modules: [{ key: "m1", name: "Bare Module", sections: [] }]
        })
      end

      it "does not modify project attribute_schema" do
        project.update!(attribute_schema: [{ "name" => "Existing", "type" => "text" }])
        bare_template.apply_to_project!(project)
        project.reload
        expect(project.attribute_schema.first["name"]).to eq("Existing")
      end
    end

    context "with modules that have no sections" do
      let(:no_sections_template) do
        create(:compliance_template, template_data: {
          modules: [{ key: "empty_mod", name: "Empty Module" }]
        })
      end

      it "creates the module without sections" do
        no_sections_template.apply_to_project!(project)
        mod = project.requirement_modules.find_by(name: "Empty Module")
        expect(mod).to be_present
        expect(mod.sections.count).to eq(0)
      end
    end
  end

  describe "#expected_links" do
    it "returns expected link definitions from template_data" do
      template = create(:compliance_template)
      links = template.expected_links
      expect(links.length).to eq(1)
      expect(links.first[:source_module]).to eq("mod_a")
      expect(links.first[:target_module]).to eq("mod_b")
      expect(links.first[:link_type]).to eq("derives_from")
    end

    it "returns empty array when no expected_links defined" do
      template = create(:compliance_template, template_data: { modules: [] })
      expect(template.expected_links).to eq([])
    end

    context "with ISO 26262 template" do
      it "defines 6 expected link relationships" do
        template = build(:compliance_template, :iso_26262)
        expect(template.expected_links.length).to eq(6)
      end

      it "includes V-model traceability chain link types" do
        template = build(:compliance_template, :iso_26262)
        link_types = template.expected_links.map { |l| l[:link_type] }
        expect(link_types).to include("derives_from", "satisfies", "refines", "verifies")
      end
    end

    context "with ASPICE template" do
      it "defines 6 expected link relationships" do
        template = build(:compliance_template, :aspice)
        expect(template.expected_links.length).to eq(6)
      end

      it "includes process area traceability link types" do
        template = build(:compliance_template, :aspice)
        link_types = template.expected_links.map { |l| l[:link_type] }
        expect(link_types).to include("derives_from", "refines", "verifies", "implements")
      end
    end
  end

  describe "#phases" do
    it "returns phase information from template modules" do
      template = create(:compliance_template)
      phases = template.phases
      expect(phases.length).to eq(2)
      expect(phases.first[:key]).to eq("mod_a")
      expect(phases.first[:name]).to eq("Module A")
      expect(phases.first[:description]).to eq("First module")
    end

    it "returns empty array when no modules defined" do
      template = create(:compliance_template, template_data: { modules: [] })
      expect(template.phases).to eq([])
    end
  end

  describe ".iso_26262_template_data" do
    let(:data) { described_class.iso_26262_template_data }

    it "includes attribute_schema" do
      expect(data[:attribute_schema]).to be_an(Array)
      expect(data[:attribute_schema].length).to eq(4)
    end

    it "defines 7 V-model modules" do
      expect(data[:modules].length).to eq(7)
    end

    it "has unique module keys" do
      keys = data[:modules].map { |m| m[:key] }
      expect(keys).to eq(keys.uniq)
    end

    it "defines all V-model phases" do
      module_names = data[:modules].map { |m| m[:name] }
      expect(module_names).to include(
        "System Requirements",
        "Software Requirements",
        "Software Architecture",
        "Software Detailed Design",
        "Unit Test Specifications",
        "Integration Test Specifications",
        "System Test Specifications"
      )
    end

    it "has sections for every module" do
      data[:modules].each do |mod|
        expect(mod[:sections]).to be_present, "Module #{mod[:name]} has no sections"
      end
    end

    it "uses valid link types in expected_links" do
      valid_types = TraceabilityLink.link_types.keys
      data[:expected_links].each do |link|
        expect(valid_types).to include(link[:link_type]), "Invalid link type: #{link[:link_type]}"
      end
    end

    it "references only defined module keys in expected_links" do
      module_keys = data[:modules].map { |m| m[:key] }
      data[:expected_links].each do |link|
        expect(module_keys).to include(link[:source_module]), "Unknown source: #{link[:source_module]}"
        expect(module_keys).to include(link[:target_module]), "Unknown target: #{link[:target_module]}"
      end
    end
  end

  describe ".aspice_template_data" do
    let(:data) { described_class.aspice_template_data }

    it "includes attribute_schema" do
      expect(data[:attribute_schema]).to be_an(Array)
      expect(data[:attribute_schema].length).to eq(4)
    end

    it "defines 9 process area modules" do
      expect(data[:modules].length).to eq(9)
    end

    it "has unique module keys" do
      keys = data[:modules].map { |m| m[:key] }
      expect(keys).to eq(keys.uniq)
    end

    it "includes SWE.1 through SWE.6 process areas" do
      module_names = data[:modules].map { |m| m[:name] }
      (1..6).each do |n|
        expect(module_names.any? { |name| name.include?("SWE.#{n}") }).to be(true), "Missing SWE.#{n}"
      end
    end

    it "includes SUP.7, SUP.9, and SUP.10 supporting processes" do
      module_names = data[:modules].map { |m| m[:name] }
      %w[SUP.7 SUP.9 SUP.10].each do |sup|
        expect(module_names.any? { |name| name.include?(sup) }).to be(true), "Missing #{sup}"
      end
    end

    it "has sections for every module" do
      data[:modules].each do |mod|
        expect(mod[:sections]).to be_present, "Module #{mod[:name]} has no sections"
      end
    end

    it "uses valid link types in expected_links" do
      valid_types = TraceabilityLink.link_types.keys
      data[:expected_links].each do |link|
        expect(valid_types).to include(link[:link_type]), "Invalid link type: #{link[:link_type]}"
      end
    end

    it "references only defined module keys in expected_links" do
      module_keys = data[:modules].map { |m| m[:key] }
      data[:expected_links].each do |link|
        expect(module_keys).to include(link[:source_module]), "Unknown source: #{link[:source_module]}"
        expect(module_keys).to include(link[:target_module]), "Unknown target: #{link[:target_module]}"
      end
    end
  end

  describe ".seed_templates!" do
    it "creates ISO 26262 and ASPICE templates" do
      expect { described_class.seed_templates! }.to change(described_class, :count).by(2)
    end

    it "creates the ISO 26262 template" do
      described_class.seed_templates!
      iso = described_class.find_by(standard: "iso_26262")
      expect(iso.name).to eq("ISO 26262 — Functional Safety")
      expect(iso.active).to be true
      expect(iso.template_data["modules"].length).to eq(7)
    end

    it "creates the ASPICE template" do
      described_class.seed_templates!
      aspice = described_class.find_by(standard: "aspice")
      expect(aspice.name).to eq("Automotive SPICE (ASPICE)")
      expect(aspice.active).to be true
      expect(aspice.template_data["modules"].length).to eq(9)
    end

    it "is idempotent — does not create duplicates" do
      described_class.seed_templates!
      expect { described_class.seed_templates! }.not_to change(described_class, :count)
    end

    it "does not overwrite existing templates" do
      described_class.seed_templates!
      iso = described_class.find_by(standard: "iso_26262")
      iso.update!(description: "Custom description")
      described_class.seed_templates!
      iso.reload
      expect(iso.description).to eq("Custom description")
    end
  end
end
