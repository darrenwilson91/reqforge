require "rails_helper"
require "rexml/document"

RSpec.describe ReqifExporter do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:project) { create(:project, organization: organization, prefix: "REQ", name: "Test Project") }
  let(:mod) { create(:requirement_module, project: project, name: "System Requirements") }
  let(:section) { create(:section, requirement_module: mod, name: "Functional") }

  subject(:exporter) { described_class.new(project) }

  def parse_xml(xml_string)
    REXML::Document.new(xml_string)
  end

  def xpath(doc, path)
    REXML::XPath.match(doc, path)
  end

  def xpath_first(doc, path)
    REXML::XPath.first(doc, path)
  end

  describe "#export" do
    context "with an empty project" do
      it "returns valid XML with ReqIF root element" do
        doc = parse_xml(exporter.export)
        root = doc.root
        expect(root.name).to eq("REQ-IF")
        expect(root.namespace).to eq(ReqifExporter::REQIF_NAMESPACE)
      end

      it "includes XML declaration" do
        xml = exporter.export
        expect(xml).to start_with('<?xml version="1.0" encoding="UTF-8"?>')
      end

      it "includes THE-HEADER with project metadata" do
        doc = parse_xml(exporter.export)
        header = xpath_first(doc, "//REQ-IF-HEADER")

        expect(header).not_to be_nil
        expect(xpath_first(doc, "//REQ-IF-HEADER/TITLE").text).to eq("Test Project")
        expect(xpath_first(doc, "//REQ-IF-HEADER/REQ-IF-TOOL-ID").text).to eq("ReqForge")
        expect(xpath_first(doc, "//REQ-IF-HEADER/REQ-IF-VERSION").text).to eq("1.2")
        expect(xpath_first(doc, "//REQ-IF-HEADER/SOURCE-TOOL-ID").text).to eq("ReqForge")
        expect(xpath_first(doc, "//REQ-IF-HEADER/COMMENT").text).to eq("Exported from ReqForge")
      end

      it "includes CORE-CONTENT element" do
        doc = parse_xml(exporter.export)
        expect(xpath_first(doc, "//CORE-CONTENT/REQ-IF-CONTENT")).not_to be_nil
      end

      it "includes DATATYPES with string and xhtml types" do
        doc = parse_xml(exporter.export)
        datatypes = xpath(doc, "//DATATYPES/*")
        names = datatypes.map { |dt| dt.attributes["LONG-NAME"] }.compact
        expect(names).to include("String", "XHTML")
      end

      it "includes enum datatypes for requirement attributes" do
        doc = parse_xml(exporter.export)
        enum_dts = xpath(doc, "//DATATYPES/DATATYPE-DEFINITION-ENUMERATION")
        enum_names = enum_dts.map { |dt| dt.attributes["LONG-NAME"] }

        expect(enum_names).to include(
          "Requirement Type", "Status", "Priority", "ASIL Level", "Link Type"
        )
      end

      it "includes enum values for requirement type" do
        doc = parse_xml(exporter.export)
        req_type_dt = xpath(doc, "//DATATYPES/DATATYPE-DEFINITION-ENUMERATION").find do |dt|
          dt.attributes["LONG-NAME"] == "Requirement Type"
        end
        enum_values = xpath(req_type_dt, ".//ENUM-VALUE")
        long_names = enum_values.map { |ev| ev.attributes["LONG-NAME"] }

        expect(long_names).to include("Functional", "Non Functional", "Safety", "Interface", "Design Constraint")
      end

      it "includes SPEC-TYPES for requirements, links, and specifications" do
        doc = parse_xml(exporter.export)
        spec_obj_type = xpath_first(doc, "//SPEC-TYPES/SPEC-OBJECT-TYPE")
        spec_rel_type = xpath_first(doc, "//SPEC-TYPES/SPEC-RELATION-TYPE")
        spec_type = xpath_first(doc, "//SPEC-TYPES/SPECIFICATION-TYPE")

        expect(spec_obj_type).not_to be_nil
        expect(spec_obj_type.attributes["LONG-NAME"]).to eq("Requirement")
        expect(spec_rel_type).not_to be_nil
        expect(spec_rel_type.attributes["LONG-NAME"]).to eq("Traceability Link")
        expect(spec_type).not_to be_nil
        expect(spec_type.attributes["LONG-NAME"]).to eq("Requirements Specification")
      end

      it "includes attribute definitions for requirements" do
        doc = parse_xml(exporter.export)
        req_type = xpath_first(doc, "//SPEC-TYPES/SPEC-OBJECT-TYPE")
        attr_names = xpath(req_type, ".//SPEC-ATTRIBUTES//*[@LONG-NAME]").map do |a|
          a.attributes["LONG-NAME"]
        end

        expect(attr_names).to include("UID", "Title", "Body", "Requirement Type",
          "Status", "Priority", "ASIL Level", "Module Name", "Section Name")
      end

      it "includes empty SPEC-OBJECTS for empty project" do
        doc = parse_xml(exporter.export)
        spec_objects = xpath_first(doc, "//SPEC-OBJECTS")
        expect(spec_objects).not_to be_nil
        expect(xpath(doc, "//SPEC-OBJECTS/SPEC-OBJECT")).to be_empty
      end

      it "includes empty SPEC-RELATIONS for empty project" do
        doc = parse_xml(exporter.export)
        spec_relations = xpath_first(doc, "//SPEC-RELATIONS")
        expect(spec_relations).not_to be_nil
        expect(xpath(doc, "//SPEC-RELATIONS/SPEC-RELATION")).to be_empty
      end

      it "includes SPECIFICATIONS with project name" do
        doc = parse_xml(exporter.export)
        spec = xpath_first(doc, "//SPECIFICATIONS/SPECIFICATION")
        expect(spec).not_to be_nil
        expect(spec.attributes["LONG-NAME"]).to eq("Test Project")
      end

      it "includes TOOL-EXTENSIONS element" do
        doc = parse_xml(exporter.export)
        expect(xpath_first(doc, "//TOOL-EXTENSIONS")).not_to be_nil
      end
    end

    context "with requirements" do
      let!(:req1) do
        create(:requirement,
          project: project,
          section: section,
          created_by: user,
          uid: "REQ-0001",
          title: "System shall start within 5 seconds",
          body: "The system must boot up in under 5 seconds.",
          requirement_type: :functional,
          status: :approved,
          priority: :must_have,
          asil_level: :asil_b)
      end

      let!(:req2) do
        create(:requirement,
          project: project,
          section: section,
          created_by: user,
          uid: "REQ-0002",
          title: "System shall log errors",
          body: "All errors shall be logged to persistent storage.",
          requirement_type: :non_functional,
          status: :draft,
          priority: :should_have,
          asil_level: :qm)
      end

      it "exports all requirements as SPEC-OBJECTS" do
        doc = parse_xml(exporter.export)
        spec_objects = xpath(doc, "//SPEC-OBJECTS/SPEC-OBJECT")
        expect(spec_objects.length).to eq(2)
      end

      it "exports requirement UIDs as LONG-NAME" do
        doc = parse_xml(exporter.export)
        spec_objects = xpath(doc, "//SPEC-OBJECTS/SPEC-OBJECT")
        long_names = spec_objects.map { |so| so.attributes["LONG-NAME"] }
        expect(long_names).to contain_exactly("REQ-0001", "REQ-0002")
      end

      it "exports requirement title as string attribute" do
        doc = parse_xml(exporter.export)
        so = xpath(doc, "//SPEC-OBJECTS/SPEC-OBJECT").find do |obj|
          obj.attributes["LONG-NAME"] == "REQ-0001"
        end
        title_val = xpath(so, ".//ATTRIBUTE-VALUE-STRING").find do |av|
          xpath_first(av, ".//ATTRIBUTE-DEFINITION-STRING-REF")&.text&.end_with?("ad-title")
        end
        expect(title_val.attributes["THE-VALUE"]).to eq("System shall start within 5 seconds")
      end

      it "exports requirement body as XHTML attribute" do
        doc = parse_xml(exporter.export)
        so = xpath(doc, "//SPEC-OBJECTS/SPEC-OBJECT").find do |obj|
          obj.attributes["LONG-NAME"] == "REQ-0001"
        end
        body_val = xpath_first(so, ".//ATTRIBUTE-VALUE-XHTML")
        xhtml_div = xpath_first(body_val, ".//xhtml:div")
        expect(xhtml_div.text).to eq("The system must boot up in under 5 seconds.")
      end

      it "exports requirement type as enum value reference" do
        doc = parse_xml(exporter.export)
        so = xpath(doc, "//SPEC-OBJECTS/SPEC-OBJECT").find do |obj|
          obj.attributes["LONG-NAME"] == "REQ-0001"
        end
        enum_vals = xpath(so, ".//ATTRIBUTE-VALUE-ENUMERATION")
        type_val = enum_vals.find do |ev|
          xpath_first(ev, ".//ATTRIBUTE-DEFINITION-ENUMERATION-REF")&.text&.end_with?("ad-requirement-type")
        end
        enum_ref = xpath_first(type_val, ".//ENUM-VALUE-REF")
        expect(enum_ref.text).to end_with("ev-requirement-type-functional")
      end

      it "exports status as enum value reference" do
        doc = parse_xml(exporter.export)
        so = xpath(doc, "//SPEC-OBJECTS/SPEC-OBJECT").find do |obj|
          obj.attributes["LONG-NAME"] == "REQ-0001"
        end
        enum_vals = xpath(so, ".//ATTRIBUTE-VALUE-ENUMERATION")
        status_val = enum_vals.find do |ev|
          xpath_first(ev, ".//ATTRIBUTE-DEFINITION-ENUMERATION-REF")&.text&.end_with?("ad-status")
        end
        enum_ref = xpath_first(status_val, ".//ENUM-VALUE-REF")
        expect(enum_ref.text).to end_with("ev-status-approved")
      end

      it "exports ASIL level as enum value reference" do
        doc = parse_xml(exporter.export)
        so = xpath(doc, "//SPEC-OBJECTS/SPEC-OBJECT").find do |obj|
          obj.attributes["LONG-NAME"] == "REQ-0001"
        end
        enum_vals = xpath(so, ".//ATTRIBUTE-VALUE-ENUMERATION")
        asil_val = enum_vals.find do |ev|
          xpath_first(ev, ".//ATTRIBUTE-DEFINITION-ENUMERATION-REF")&.text&.end_with?("ad-asil-level")
        end
        enum_ref = xpath_first(asil_val, ".//ENUM-VALUE-REF")
        expect(enum_ref.text).to end_with("ev-asil-level-asil_b")
      end

      it "exports module name as string attribute" do
        doc = parse_xml(exporter.export)
        so = xpath(doc, "//SPEC-OBJECTS/SPEC-OBJECT").first
        mod_val = xpath(so, ".//ATTRIBUTE-VALUE-STRING").find do |av|
          xpath_first(av, ".//ATTRIBUTE-DEFINITION-STRING-REF")&.text&.end_with?("ad-module-name")
        end
        expect(mod_val.attributes["THE-VALUE"]).to eq("System Requirements")
      end

      it "exports section name as string attribute" do
        doc = parse_xml(exporter.export)
        so = xpath(doc, "//SPEC-OBJECTS/SPEC-OBJECT").first
        sec_val = xpath(so, ".//ATTRIBUTE-VALUE-STRING").find do |av|
          xpath_first(av, ".//ATTRIBUTE-DEFINITION-STRING-REF")&.text&.end_with?("ad-section-name")
        end
        expect(sec_val.attributes["THE-VALUE"]).to eq("Functional")
      end

      it "references SPEC-OBJECT-TYPE in each requirement" do
        doc = parse_xml(exporter.export)
        spec_objects = xpath(doc, "//SPEC-OBJECTS/SPEC-OBJECT")
        spec_objects.each do |so|
          type_ref = xpath_first(so, ".//TYPE/SPEC-OBJECT-TYPE-REF")
          expect(type_ref).not_to be_nil
          expect(type_ref.text).to end_with("sot-requirement")
        end
      end

      it "includes LAST-CHANGE timestamp on each SPEC-OBJECT" do
        doc = parse_xml(exporter.export)
        spec_objects = xpath(doc, "//SPEC-OBJECTS/SPEC-OBJECT")
        spec_objects.each do |so|
          expect(so.attributes["LAST-CHANGE"]).not_to be_nil
          expect { Time.iso8601(so.attributes["LAST-CHANGE"]) }.not_to raise_error
        end
      end
    end

    context "with traceability links" do
      let!(:req1) do
        create(:requirement, project: project, section: section, created_by: user,
          uid: "REQ-0001", title: "Source requirement")
      end

      let!(:req2) do
        create(:requirement, project: project, section: section, created_by: user,
          uid: "REQ-0002", title: "Target requirement")
      end

      let!(:link) do
        create(:traceability_link,
          source_requirement: req1,
          target_requirement: req2,
          link_type: :derives_from,
          description: "Derived from system requirement",
          created_by: user)
      end

      it "exports links as SPEC-RELATIONS" do
        doc = parse_xml(exporter.export)
        spec_relations = xpath(doc, "//SPEC-RELATIONS/SPEC-RELATION")
        expect(spec_relations.length).to eq(1)
      end

      it "includes link LONG-NAME with source and target UIDs" do
        doc = parse_xml(exporter.export)
        spec_rel = xpath_first(doc, "//SPEC-RELATIONS/SPEC-RELATION")
        expect(spec_rel.attributes["LONG-NAME"]).to eq("REQ-0001 -> REQ-0002")
      end

      it "references source SPEC-OBJECT" do
        doc = parse_xml(exporter.export)
        source_ref = xpath_first(doc, "//SPEC-RELATION/SOURCE/SPEC-OBJECT-REF")
        expect(source_ref).not_to be_nil
        expect(source_ref.text).to end_with("so-#{req1.id}")
      end

      it "references target SPEC-OBJECT" do
        doc = parse_xml(exporter.export)
        target_ref = xpath_first(doc, "//SPEC-RELATION/TARGET/SPEC-OBJECT-REF")
        expect(target_ref).not_to be_nil
        expect(target_ref.text).to end_with("so-#{req2.id}")
      end

      it "includes link type as enum value" do
        doc = parse_xml(exporter.export)
        spec_rel = xpath_first(doc, "//SPEC-RELATIONS/SPEC-RELATION")
        enum_ref = xpath_first(spec_rel, ".//ENUM-VALUE-REF")
        expect(enum_ref.text).to end_with("ev-link-type-derives_from")
      end

      it "includes link description as string attribute" do
        doc = parse_xml(exporter.export)
        spec_rel = xpath_first(doc, "//SPEC-RELATIONS/SPEC-RELATION")
        desc_val = xpath(spec_rel, ".//ATTRIBUTE-VALUE-STRING").find do |av|
          xpath_first(av, ".//ATTRIBUTE-DEFINITION-STRING-REF")&.text&.end_with?("ad-description")
        end
        expect(desc_val.attributes["THE-VALUE"]).to eq("Derived from system requirement")
      end

      it "references SPEC-RELATION-TYPE" do
        doc = parse_xml(exporter.export)
        type_ref = xpath_first(doc, "//SPEC-RELATION/TYPE/SPEC-RELATION-TYPE-REF")
        expect(type_ref).not_to be_nil
        expect(type_ref.text).to end_with("srt-link")
      end

      it "includes LAST-CHANGE on SPEC-RELATION" do
        doc = parse_xml(exporter.export)
        spec_rel = xpath_first(doc, "//SPEC-RELATIONS/SPEC-RELATION")
        expect(spec_rel.attributes["LAST-CHANGE"]).not_to be_nil
      end
    end

    context "with cross-project links excluded" do
      let(:other_project) { create(:project, organization: organization, prefix: "OTH") }
      let(:other_mod) { create(:requirement_module, project: other_project, name: "Other") }
      let(:other_section) { create(:section, requirement_module: other_mod, name: "Other") }

      let!(:our_req) do
        create(:requirement, project: project, section: section, created_by: user,
          uid: "REQ-0001", title: "Our requirement")
      end

      let!(:other_req) do
        create(:requirement, project: other_project, section: other_section, created_by: user,
          uid: "OTH-0001", title: "Other requirement")
      end

      let!(:cross_link) do
        create(:traceability_link,
          source_requirement: our_req,
          target_requirement: other_req,
          link_type: :derives_from,
          created_by: user)
      end

      it "only exports links where both endpoints are in the project" do
        doc = parse_xml(exporter.export)
        spec_relations = xpath(doc, "//SPEC-RELATIONS/SPEC-RELATION")
        expect(spec_relations).to be_empty
      end

      it "only exports requirements belonging to the project" do
        doc = parse_xml(exporter.export)
        spec_objects = xpath(doc, "//SPEC-OBJECTS/SPEC-OBJECT")
        expect(spec_objects.length).to eq(1)
        expect(spec_objects.first.attributes["LONG-NAME"]).to eq("REQ-0001")
      end
    end

    context "with hierarchical structure" do
      let(:mod1) { create(:requirement_module, project: project, name: "Module A", position: 1) }
      let(:mod2) { create(:requirement_module, project: project, name: "Module B", position: 2) }
      let(:section1) { create(:section, requirement_module: mod1, name: "Section 1") }
      let(:section2) { create(:section, requirement_module: mod2, name: "Section 2") }
      let(:child_section) { create(:section, requirement_module: mod1, name: "Child Section", parent_section: section1) }

      let!(:req1) do
        create(:requirement, project: project, section: section1, created_by: user,
          uid: "REQ-0001", title: "Req in Section 1")
      end

      let!(:req2) do
        create(:requirement, project: project, section: section2, created_by: user,
          uid: "REQ-0002", title: "Req in Section 2")
      end

      let!(:req3) do
        create(:requirement, project: project, section: child_section, created_by: user,
          uid: "REQ-0003", title: "Req in Child Section")
      end

      it "creates SPEC-HIERARCHY for each module" do
        doc = parse_xml(exporter.export)
        spec = xpath_first(doc, "//SPECIFICATIONS/SPECIFICATION")
        top_level = xpath(spec, "./CHILDREN/SPEC-HIERARCHY")
        mod_names = top_level.map { |sh| sh.attributes["LONG-NAME"] }
        expect(mod_names).to include("Module A", "Module B")
      end

      it "nests sections under modules in SPEC-HIERARCHY" do
        doc = parse_xml(exporter.export)
        mod_a = xpath(doc, "//SPECIFICATION/CHILDREN/SPEC-HIERARCHY").find do |sh|
          sh.attributes["LONG-NAME"] == "Module A"
        end
        section_nodes = xpath(mod_a, "./CHILDREN/SPEC-HIERARCHY")
        section_names = section_nodes.map { |sh| sh.attributes["LONG-NAME"] }
        expect(section_names).to include("Section 1")
      end

      it "nests requirements under sections with SPEC-OBJECT-REF" do
        doc = parse_xml(exporter.export)
        # Find Section 1 under Module A
        mod_a = xpath(doc, "//SPECIFICATION/CHILDREN/SPEC-HIERARCHY").find do |sh|
          sh.attributes["LONG-NAME"] == "Module A"
        end
        section_1 = xpath(mod_a, "./CHILDREN/SPEC-HIERARCHY").find do |sh|
          sh.attributes["LONG-NAME"] == "Section 1"
        end
        req_refs = xpath(section_1, "./CHILDREN/SPEC-HIERARCHY/OBJECT/SPEC-OBJECT-REF")
        expect(req_refs.length).to eq(1)
        expect(req_refs.first.text).to end_with("so-#{req1.id}")
      end

      it "supports nested child sections" do
        doc = parse_xml(exporter.export)
        mod_a = xpath(doc, "//SPECIFICATION/CHILDREN/SPEC-HIERARCHY").find do |sh|
          sh.attributes["LONG-NAME"] == "Module A"
        end
        section_1 = xpath(mod_a, "./CHILDREN/SPEC-HIERARCHY").find do |sh|
          sh.attributes["LONG-NAME"] == "Section 1"
        end
        child_sections = xpath(section_1, "./CHILDREN/SPEC-HIERARCHY[@LONG-NAME]")
        child_names = child_sections.select { |sh| sh.attributes["LONG-NAME"].present? }
          .map { |sh| sh.attributes["LONG-NAME"] }
        expect(child_names).to include("Child Section")
      end

      it "places child section requirements in the correct hierarchy level" do
        doc = parse_xml(exporter.export)
        # Navigate: Specification > Module A > Section 1 > Child Section > requirement
        mod_a = xpath(doc, "//SPECIFICATION/CHILDREN/SPEC-HIERARCHY").find do |sh|
          sh.attributes["LONG-NAME"] == "Module A"
        end
        section_1 = xpath(mod_a, "./CHILDREN/SPEC-HIERARCHY").find do |sh|
          sh.attributes["LONG-NAME"] == "Section 1"
        end
        child_sec = xpath(section_1, "./CHILDREN/SPEC-HIERARCHY").find do |sh|
          sh.attributes["LONG-NAME"] == "Child Section"
        end
        req_refs = xpath(child_sec, "./CHILDREN/SPEC-HIERARCHY/OBJECT/SPEC-OBJECT-REF")
        expect(req_refs.length).to eq(1)
        expect(req_refs.first.text).to end_with("so-#{req3.id}")
      end
    end

    context "with nil body" do
      let!(:req) do
        create(:requirement, project: project, section: section, created_by: user,
          uid: "REQ-0001", title: "No body", body: nil)
      end

      it "exports empty string for nil body" do
        doc = parse_xml(exporter.export)
        body_val = xpath_first(doc, "//ATTRIBUTE-VALUE-XHTML")
        xhtml_div = xpath_first(body_val, ".//xhtml:div")
        expect(xhtml_div.text.to_s).to eq("")
      end
    end

    context "with nil link description" do
      let!(:req1) do
        create(:requirement, project: project, section: section, created_by: user,
          uid: "REQ-0001", title: "Source")
      end

      let!(:req2) do
        create(:requirement, project: project, section: section, created_by: user,
          uid: "REQ-0002", title: "Target")
      end

      let!(:link) do
        create(:traceability_link,
          source_requirement: req1, target_requirement: req2,
          link_type: :satisfies, description: nil, created_by: user)
      end

      it "exports empty string for nil description" do
        doc = parse_xml(exporter.export)
        spec_rel = xpath_first(doc, "//SPEC-RELATIONS/SPEC-RELATION")
        desc_val = xpath(spec_rel, ".//ATTRIBUTE-VALUE-STRING").find do |av|
          xpath_first(av, ".//ATTRIBUTE-DEFINITION-STRING-REF")&.text&.end_with?("ad-description")
        end
        expect(desc_val.attributes["THE-VALUE"]).to eq("")
      end
    end

    context "with multiple link types" do
      let!(:req1) do
        create(:requirement, project: project, section: section, created_by: user,
          uid: "REQ-0001", title: "Source")
      end

      let!(:req2) do
        create(:requirement, project: project, section: section, created_by: user,
          uid: "REQ-0002", title: "Target")
      end

      let!(:link1) do
        create(:traceability_link,
          source_requirement: req1, target_requirement: req2,
          link_type: :derives_from, created_by: user)
      end

      let!(:link2) do
        create(:traceability_link,
          source_requirement: req1, target_requirement: req2,
          link_type: :verifies, created_by: user)
      end

      it "exports each link as a separate SPEC-RELATION" do
        doc = parse_xml(exporter.export)
        spec_relations = xpath(doc, "//SPEC-RELATIONS/SPEC-RELATION")
        expect(spec_relations.length).to eq(2)
      end

      it "preserves different link types" do
        doc = parse_xml(exporter.export)
        spec_relations = xpath(doc, "//SPEC-RELATIONS/SPEC-RELATION")
        enum_refs = spec_relations.flat_map { |sr| xpath(sr, ".//ENUM-VALUE-REF") }
        ref_texts = enum_refs.map(&:text)
        expect(ref_texts.any? { |t| t.end_with?("ev-link-type-derives_from") }).to be true
        expect(ref_texts.any? { |t| t.end_with?("ev-link-type-verifies") }).to be true
      end
    end

    context "identifier consistency" do
      let!(:req) do
        create(:requirement, project: project, section: section, created_by: user,
          uid: "REQ-0001", title: "Test")
      end

      it "uses project-based identifier prefix" do
        doc = parse_xml(exporter.export)
        header = xpath_first(doc, "//REQ-IF-HEADER")
        expect(header.attributes["IDENTIFIER"]).to start_with("reqforge-#{project.id}-")
      end

      it "SPEC-OBJECT identifiers match SPEC-HIERARCHY references" do
        doc = parse_xml(exporter.export)
        so_id = xpath_first(doc, "//SPEC-OBJECTS/SPEC-OBJECT").attributes["IDENTIFIER"]
        ref_text = xpath_first(doc, "//SPEC-HIERARCHY/OBJECT/SPEC-OBJECT-REF").text
        expect(ref_text).to eq(so_id)
      end
    end
  end

  describe "#export_to_file" do
    let!(:req) do
      create(:requirement, project: project, section: section, created_by: user,
        uid: "REQ-0001", title: "File export test")
    end

    it "writes valid ReqIF XML to the specified file" do
      file_path = Rails.root.join("tmp", "test_reqif_#{SecureRandom.hex(4)}.reqif").to_s

      begin
        exporter.export_to_file(file_path)

        expect(File.exist?(file_path)).to be true
        doc = parse_xml(File.read(file_path))
        expect(doc.root.name).to eq("REQ-IF")
      ensure
        File.delete(file_path) if File.exist?(file_path)
      end
    end

    it "writes UTF-8 encoded content" do
      file_path = Rails.root.join("tmp", "test_reqif_utf8_#{SecureRandom.hex(4)}.reqif").to_s

      begin
        exporter.export_to_file(file_path)
        content = File.read(file_path)
        expect(content.encoding.name).to eq("UTF-8")
      ensure
        File.delete(file_path) if File.exist?(file_path)
      end
    end
  end

  describe "constants" do
    it "REQUIREMENT_TYPE_VALUES matches Requirement enum" do
      expect(ReqifExporter::REQUIREMENT_TYPE_VALUES).to eq(Requirement.requirement_types.keys)
    end

    it "STATUS_VALUES matches Requirement enum" do
      expect(ReqifExporter::STATUS_VALUES).to eq(Requirement.statuses.keys)
    end

    it "PRIORITY_VALUES matches Requirement enum" do
      expect(ReqifExporter::PRIORITY_VALUES).to eq(Requirement.priorities.keys)
    end

    it "ASIL_LEVEL_VALUES matches Requirement enum" do
      expect(ReqifExporter::ASIL_LEVEL_VALUES).to eq(Requirement.asil_levels.keys)
    end

    it "LINK_TYPE_VALUES matches TraceabilityLink enum" do
      expect(ReqifExporter::LINK_TYPE_VALUES).to eq(TraceabilityLink.link_types.keys)
    end
  end
end
