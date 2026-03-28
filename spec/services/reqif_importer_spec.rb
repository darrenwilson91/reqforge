require "rails_helper"

RSpec.describe ReqifImporter do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:project) { create(:project, organization: organization, prefix: "IMP") }
  let(:importer) { described_class.new(project, user) }

  # Helper to generate ReqIF XML from the exporter for round-trip testing
  def export_project(proj)
    ReqifExporter.new(proj).export
  end

  # Helper to build minimal valid ReqIF XML
  def build_reqif_xml(spec_objects: "", spec_relations: "", hierarchy: "")
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <REQ-IF xmlns="http://www.omg.org/spec/ReqIF/20110401/reqif.xsd">
        <THE-HEADER>
          <REQ-IF-HEADER IDENTIFIER="header-1">
            <COMMENT>Test</COMMENT>
            <CREATION-TIME>2026-01-01T00:00:00Z</CREATION-TIME>
            <REQ-IF-TOOL-ID>ReqForge</REQ-IF-TOOL-ID>
            <REQ-IF-VERSION>1.2</REQ-IF-VERSION>
            <SOURCE-TOOL-ID>ReqForge</SOURCE-TOOL-ID>
            <TITLE>Test Project</TITLE>
          </REQ-IF-HEADER>
        </THE-HEADER>
        <CORE-CONTENT>
          <REQ-IF-CONTENT>
            <DATATYPES>
              <DATATYPE-DEFINITION-STRING IDENTIFIER="dt-string" LONG-NAME="String" MAX-LENGTH="32000"/>
              <DATATYPE-DEFINITION-XHTML IDENTIFIER="dt-xhtml" LONG-NAME="XHTML"/>
              <DATATYPE-DEFINITION-ENUMERATION IDENTIFIER="dt-requirement-type" LONG-NAME="Requirement Type">
                <SPECIFIED-VALUES>
                  <ENUM-VALUE IDENTIFIER="ev-rt-functional" LONG-NAME="Functional"><PROPERTIES><EMBEDDED-VALUE KEY="0" OTHER-CONTENT="functional"/></PROPERTIES></ENUM-VALUE>
                  <ENUM-VALUE IDENTIFIER="ev-rt-non_functional" LONG-NAME="Non Functional"><PROPERTIES><EMBEDDED-VALUE KEY="1" OTHER-CONTENT="non_functional"/></PROPERTIES></ENUM-VALUE>
                  <ENUM-VALUE IDENTIFIER="ev-rt-safety" LONG-NAME="Safety"><PROPERTIES><EMBEDDED-VALUE KEY="2" OTHER-CONTENT="safety"/></PROPERTIES></ENUM-VALUE>
                  <ENUM-VALUE IDENTIFIER="ev-rt-interface" LONG-NAME="Interface"><PROPERTIES><EMBEDDED-VALUE KEY="3" OTHER-CONTENT="interface"/></PROPERTIES></ENUM-VALUE>
                  <ENUM-VALUE IDENTIFIER="ev-rt-design_constraint" LONG-NAME="Design Constraint"><PROPERTIES><EMBEDDED-VALUE KEY="4" OTHER-CONTENT="design_constraint"/></PROPERTIES></ENUM-VALUE>
                </SPECIFIED-VALUES>
              </DATATYPE-DEFINITION-ENUMERATION>
              <DATATYPE-DEFINITION-ENUMERATION IDENTIFIER="dt-status" LONG-NAME="Status">
                <SPECIFIED-VALUES>
                  <ENUM-VALUE IDENTIFIER="ev-st-draft" LONG-NAME="Draft"><PROPERTIES><EMBEDDED-VALUE KEY="0" OTHER-CONTENT="draft"/></PROPERTIES></ENUM-VALUE>
                  <ENUM-VALUE IDENTIFIER="ev-st-in_review" LONG-NAME="In Review"><PROPERTIES><EMBEDDED-VALUE KEY="1" OTHER-CONTENT="in_review"/></PROPERTIES></ENUM-VALUE>
                  <ENUM-VALUE IDENTIFIER="ev-st-approved" LONG-NAME="Approved"><PROPERTIES><EMBEDDED-VALUE KEY="2" OTHER-CONTENT="approved"/></PROPERTIES></ENUM-VALUE>
                </SPECIFIED-VALUES>
              </DATATYPE-DEFINITION-ENUMERATION>
              <DATATYPE-DEFINITION-ENUMERATION IDENTIFIER="dt-priority" LONG-NAME="Priority">
                <SPECIFIED-VALUES>
                  <ENUM-VALUE IDENTIFIER="ev-pr-must_have" LONG-NAME="Must Have"><PROPERTIES><EMBEDDED-VALUE KEY="0" OTHER-CONTENT="must_have"/></PROPERTIES></ENUM-VALUE>
                  <ENUM-VALUE IDENTIFIER="ev-pr-should_have" LONG-NAME="Should Have"><PROPERTIES><EMBEDDED-VALUE KEY="1" OTHER-CONTENT="should_have"/></PROPERTIES></ENUM-VALUE>
                </SPECIFIED-VALUES>
              </DATATYPE-DEFINITION-ENUMERATION>
              <DATATYPE-DEFINITION-ENUMERATION IDENTIFIER="dt-asil-level" LONG-NAME="ASIL Level">
                <SPECIFIED-VALUES>
                  <ENUM-VALUE IDENTIFIER="ev-al-qm" LONG-NAME="Qm"><PROPERTIES><EMBEDDED-VALUE KEY="0" OTHER-CONTENT="qm"/></PROPERTIES></ENUM-VALUE>
                  <ENUM-VALUE IDENTIFIER="ev-al-asil_b" LONG-NAME="Asil B"><PROPERTIES><EMBEDDED-VALUE KEY="2" OTHER-CONTENT="asil_b"/></PROPERTIES></ENUM-VALUE>
                  <ENUM-VALUE IDENTIFIER="ev-al-asil_d" LONG-NAME="Asil D"><PROPERTIES><EMBEDDED-VALUE KEY="4" OTHER-CONTENT="asil_d"/></PROPERTIES></ENUM-VALUE>
                </SPECIFIED-VALUES>
              </DATATYPE-DEFINITION-ENUMERATION>
              <DATATYPE-DEFINITION-ENUMERATION IDENTIFIER="dt-link-type" LONG-NAME="Link Type">
                <SPECIFIED-VALUES>
                  <ENUM-VALUE IDENTIFIER="ev-lt-derives_from" LONG-NAME="Derives From"><PROPERTIES><EMBEDDED-VALUE KEY="0" OTHER-CONTENT="derives_from"/></PROPERTIES></ENUM-VALUE>
                  <ENUM-VALUE IDENTIFIER="ev-lt-satisfies" LONG-NAME="Satisfies"><PROPERTIES><EMBEDDED-VALUE KEY="1" OTHER-CONTENT="satisfies"/></PROPERTIES></ENUM-VALUE>
                  <ENUM-VALUE IDENTIFIER="ev-lt-verifies" LONG-NAME="Verifies"><PROPERTIES><EMBEDDED-VALUE KEY="2" OTHER-CONTENT="verifies"/></PROPERTIES></ENUM-VALUE>
                </SPECIFIED-VALUES>
              </DATATYPE-DEFINITION-ENUMERATION>
            </DATATYPES>
            <SPEC-TYPES>
              <SPEC-OBJECT-TYPE IDENTIFIER="sot-requirement" LONG-NAME="Requirement">
                <SPEC-ATTRIBUTES>
                  <ATTRIBUTE-DEFINITION-STRING IDENTIFIER="ad-uid" LONG-NAME="UID"><TYPE><DATATYPE-DEFINITION-STRING-REF>dt-string</DATATYPE-DEFINITION-STRING-REF></TYPE></ATTRIBUTE-DEFINITION-STRING>
                  <ATTRIBUTE-DEFINITION-STRING IDENTIFIER="ad-title" LONG-NAME="Title"><TYPE><DATATYPE-DEFINITION-STRING-REF>dt-string</DATATYPE-DEFINITION-STRING-REF></TYPE></ATTRIBUTE-DEFINITION-STRING>
                  <ATTRIBUTE-DEFINITION-XHTML IDENTIFIER="ad-body" LONG-NAME="Body"><TYPE><DATATYPE-DEFINITION-XHTML-REF>dt-xhtml</DATATYPE-DEFINITION-XHTML-REF></TYPE></ATTRIBUTE-DEFINITION-XHTML>
                  <ATTRIBUTE-DEFINITION-ENUMERATION IDENTIFIER="ad-requirement-type" LONG-NAME="Requirement Type"><TYPE><DATATYPE-DEFINITION-ENUMERATION-REF>dt-requirement-type</DATATYPE-DEFINITION-ENUMERATION-REF></TYPE></ATTRIBUTE-DEFINITION-ENUMERATION>
                  <ATTRIBUTE-DEFINITION-ENUMERATION IDENTIFIER="ad-status" LONG-NAME="Status"><TYPE><DATATYPE-DEFINITION-ENUMERATION-REF>dt-status</DATATYPE-DEFINITION-ENUMERATION-REF></TYPE></ATTRIBUTE-DEFINITION-ENUMERATION>
                  <ATTRIBUTE-DEFINITION-ENUMERATION IDENTIFIER="ad-priority" LONG-NAME="Priority"><TYPE><DATATYPE-DEFINITION-ENUMERATION-REF>dt-priority</DATATYPE-DEFINITION-ENUMERATION-REF></TYPE></ATTRIBUTE-DEFINITION-ENUMERATION>
                  <ATTRIBUTE-DEFINITION-ENUMERATION IDENTIFIER="ad-asil-level" LONG-NAME="ASIL Level"><TYPE><DATATYPE-DEFINITION-ENUMERATION-REF>dt-asil-level</DATATYPE-DEFINITION-ENUMERATION-REF></TYPE></ATTRIBUTE-DEFINITION-ENUMERATION>
                  <ATTRIBUTE-DEFINITION-STRING IDENTIFIER="ad-module-name" LONG-NAME="Module Name"><TYPE><DATATYPE-DEFINITION-STRING-REF>dt-string</DATATYPE-DEFINITION-STRING-REF></TYPE></ATTRIBUTE-DEFINITION-STRING>
                  <ATTRIBUTE-DEFINITION-STRING IDENTIFIER="ad-section-name" LONG-NAME="Section Name"><TYPE><DATATYPE-DEFINITION-STRING-REF>dt-string</DATATYPE-DEFINITION-STRING-REF></TYPE></ATTRIBUTE-DEFINITION-STRING>
                </SPEC-ATTRIBUTES>
              </SPEC-OBJECT-TYPE>
              <SPEC-RELATION-TYPE IDENTIFIER="srt-link" LONG-NAME="Traceability Link">
                <SPEC-ATTRIBUTES>
                  <ATTRIBUTE-DEFINITION-ENUMERATION IDENTIFIER="ad-link-type" LONG-NAME="Link Type"><TYPE><DATATYPE-DEFINITION-ENUMERATION-REF>dt-link-type</DATATYPE-DEFINITION-ENUMERATION-REF></TYPE></ATTRIBUTE-DEFINITION-ENUMERATION>
                  <ATTRIBUTE-DEFINITION-STRING IDENTIFIER="ad-description" LONG-NAME="Description"><TYPE><DATATYPE-DEFINITION-STRING-REF>dt-string</DATATYPE-DEFINITION-STRING-REF></TYPE></ATTRIBUTE-DEFINITION-STRING>
                </SPEC-ATTRIBUTES>
              </SPEC-RELATION-TYPE>
              <SPECIFICATION-TYPE IDENTIFIER="st-specification" LONG-NAME="Requirements Specification"/>
            </SPEC-TYPES>
            <SPEC-OBJECTS>
              #{spec_objects}
            </SPEC-OBJECTS>
            <SPEC-RELATIONS>
              #{spec_relations}
            </SPEC-RELATIONS>
            <SPECIFICATIONS>
              <SPECIFICATION IDENTIFIER="spec-1" LONG-NAME="Test">
                <TYPE><SPECIFICATION-TYPE-REF>st-specification</SPECIFICATION-TYPE-REF></TYPE>
                <CHILDREN>
                  #{hierarchy}
                </CHILDREN>
              </SPECIFICATION>
            </SPECIFICATIONS>
          </REQ-IF-CONTENT>
        </CORE-CONTENT>
        <TOOL-EXTENSIONS/>
      </REQ-IF>
    XML
  end

  def spec_object(id:, uid: nil, title:, body: nil, requirement_type: nil, status: nil, priority: nil, asil_level: nil, module_name: nil, section_name: nil)
    values = []
    values << %(<ATTRIBUTE-VALUE-STRING THE-VALUE="#{uid}"><DEFINITION><ATTRIBUTE-DEFINITION-STRING-REF>ad-uid</ATTRIBUTE-DEFINITION-STRING-REF></DEFINITION></ATTRIBUTE-VALUE-STRING>) if uid
    values << %(<ATTRIBUTE-VALUE-STRING THE-VALUE="#{title}"><DEFINITION><ATTRIBUTE-DEFINITION-STRING-REF>ad-title</ATTRIBUTE-DEFINITION-STRING-REF></DEFINITION></ATTRIBUTE-VALUE-STRING>)
    if body
      values << %(<ATTRIBUTE-VALUE-XHTML><THE-VALUE><xhtml:div xmlns:xhtml="http://www.w3.org/1999/xhtml">#{body}</xhtml:div></THE-VALUE><DEFINITION><ATTRIBUTE-DEFINITION-XHTML-REF>ad-body</ATTRIBUTE-DEFINITION-XHTML-REF></DEFINITION></ATTRIBUTE-VALUE-XHTML>)
    end
    values << %(<ATTRIBUTE-VALUE-ENUMERATION><VALUES><ENUM-VALUE-REF>ev-rt-#{requirement_type}</ENUM-VALUE-REF></VALUES><DEFINITION><ATTRIBUTE-DEFINITION-ENUMERATION-REF>ad-requirement-type</ATTRIBUTE-DEFINITION-ENUMERATION-REF></DEFINITION></ATTRIBUTE-VALUE-ENUMERATION>) if requirement_type
    values << %(<ATTRIBUTE-VALUE-ENUMERATION><VALUES><ENUM-VALUE-REF>ev-st-#{status}</ENUM-VALUE-REF></VALUES><DEFINITION><ATTRIBUTE-DEFINITION-ENUMERATION-REF>ad-status</ATTRIBUTE-DEFINITION-ENUMERATION-REF></DEFINITION></ATTRIBUTE-VALUE-ENUMERATION>) if status
    values << %(<ATTRIBUTE-VALUE-ENUMERATION><VALUES><ENUM-VALUE-REF>ev-pr-#{priority}</ENUM-VALUE-REF></VALUES><DEFINITION><ATTRIBUTE-DEFINITION-ENUMERATION-REF>ad-priority</ATTRIBUTE-DEFINITION-ENUMERATION-REF></DEFINITION></ATTRIBUTE-VALUE-ENUMERATION>) if priority
    values << %(<ATTRIBUTE-VALUE-ENUMERATION><VALUES><ENUM-VALUE-REF>ev-al-#{asil_level}</ENUM-VALUE-REF></VALUES><DEFINITION><ATTRIBUTE-DEFINITION-ENUMERATION-REF>ad-asil-level</ATTRIBUTE-DEFINITION-ENUMERATION-REF></DEFINITION></ATTRIBUTE-VALUE-ENUMERATION>) if asil_level
    values << %(<ATTRIBUTE-VALUE-STRING THE-VALUE="#{module_name}"><DEFINITION><ATTRIBUTE-DEFINITION-STRING-REF>ad-module-name</ATTRIBUTE-DEFINITION-STRING-REF></DEFINITION></ATTRIBUTE-VALUE-STRING>) if module_name
    values << %(<ATTRIBUTE-VALUE-STRING THE-VALUE="#{section_name}"><DEFINITION><ATTRIBUTE-DEFINITION-STRING-REF>ad-section-name</ATTRIBUTE-DEFINITION-STRING-REF></DEFINITION></ATTRIBUTE-VALUE-STRING>) if section_name

    <<~XML
      <SPEC-OBJECT IDENTIFIER="#{id}" LONG-NAME="#{uid || title}" LAST-CHANGE="2026-01-01T00:00:00Z">
        <VALUES>#{values.join("\n")}</VALUES>
        <TYPE><SPEC-OBJECT-TYPE-REF>sot-requirement</SPEC-OBJECT-TYPE-REF></TYPE>
      </SPEC-OBJECT>
    XML
  end

  def spec_relation(id:, source_ref:, target_ref:, link_type:, description: nil)
    values = []
    values << %(<ATTRIBUTE-VALUE-ENUMERATION><VALUES><ENUM-VALUE-REF>ev-lt-#{link_type}</ENUM-VALUE-REF></VALUES><DEFINITION><ATTRIBUTE-DEFINITION-ENUMERATION-REF>ad-link-type</ATTRIBUTE-DEFINITION-ENUMERATION-REF></DEFINITION></ATTRIBUTE-VALUE-ENUMERATION>)
    values << %(<ATTRIBUTE-VALUE-STRING THE-VALUE="#{description}"><DEFINITION><ATTRIBUTE-DEFINITION-STRING-REF>ad-description</ATTRIBUTE-DEFINITION-STRING-REF></DEFINITION></ATTRIBUTE-VALUE-STRING>) if description

    <<~XML
      <SPEC-RELATION IDENTIFIER="#{id}" LONG-NAME="link" LAST-CHANGE="2026-01-01T00:00:00Z">
        <VALUES>#{values.join("\n")}</VALUES>
        <TYPE><SPEC-RELATION-TYPE-REF>srt-link</SPEC-RELATION-TYPE-REF></TYPE>
        <SOURCE><SPEC-OBJECT-REF>#{source_ref}</SPEC-OBJECT-REF></SOURCE>
        <TARGET><SPEC-OBJECT-REF>#{target_ref}</SPEC-OBJECT-REF></TARGET>
      </SPEC-RELATION>
    XML
  end

  def hierarchy_module(name:, children: "")
    <<~XML
      <SPEC-HIERARCHY IDENTIFIER="sh-mod-1" LONG-NAME="#{name}">
        <CHILDREN>#{children}</CHILDREN>
      </SPEC-HIERARCHY>
    XML
  end

  def hierarchy_section(name:, children: "")
    <<~XML
      <SPEC-HIERARCHY IDENTIFIER="sh-sec-1" LONG-NAME="#{name}">
        <CHILDREN>#{children}</CHILDREN>
      </SPEC-HIERARCHY>
    XML
  end

  def hierarchy_req(ref:)
    <<~XML
      <SPEC-HIERARCHY IDENTIFIER="sh-req-1">
        <OBJECT><SPEC-OBJECT-REF>#{ref}</SPEC-OBJECT-REF></OBJECT>
      </SPEC-HIERARCHY>
    XML
  end

  describe "#initialize" do
    it "sets project and user" do
      expect(importer.project).to eq(project)
    end

    it "initializes counters to zero" do
      expect(importer.imported_requirements_count).to eq(0)
      expect(importer.imported_links_count).to eq(0)
      expect(importer.skipped_count).to eq(0)
      expect(importer.errors).to be_empty
    end
  end

  describe "#import" do
    context "with a single valid requirement" do
      let(:xml) do
        build_reqif_xml(
          spec_objects: spec_object(
            id: "so-1", uid: "EXT-0001", title: "Braking System",
            body: "The system shall provide braking functionality.",
            requirement_type: "safety", status: "draft",
            priority: "must_have", asil_level: "asil_d"
          )
        )
      end

      it "imports the requirement" do
        result = importer.import(xml)
        expect(result[:success]).to be true
        expect(result[:imported_requirements]).to eq(1)
      end

      it "sets all attributes correctly" do
        importer.import(xml)
        req = project.requirements.reload.first
        expect(req.uid).to eq("EXT-0001")
        expect(req.title).to eq("Braking System")
        expect(req.body).to eq("The system shall provide braking functionality.")
        expect(req.requirement_type).to eq("safety")
        expect(req.status).to eq("draft")
        expect(req.priority).to eq("must_have")
        expect(req.asil_level).to eq("asil_d")
      end

      it "assigns created_by to the importing user" do
        importer.import(xml)
        req = project.requirements.reload.first
        expect(req.created_by).to eq(user)
      end

      it "creates module and section" do
        importer.import(xml)
        expect(project.requirement_modules.count).to eq(1)
        expect(project.requirement_modules.first.name).to eq("Imported")
      end
    end

    context "with UID auto-generation" do
      let(:xml) do
        build_reqif_xml(
          spec_objects: spec_object(id: "so-1", title: "No UID requirement")
        )
      end

      it "auto-generates a UID when not provided" do
        importer.import(xml)
        req = project.requirements.reload.first
        expect(req.uid).to match(/\AIMP-\d{4}\z/)
      end
    end

    context "with multiple requirements" do
      let(:xml) do
        build_reqif_xml(
          spec_objects: [
            spec_object(id: "so-1", uid: "EXT-0001", title: "Req 1", requirement_type: "functional"),
            spec_object(id: "so-2", uid: "EXT-0002", title: "Req 2", requirement_type: "safety"),
            spec_object(id: "so-3", uid: "EXT-0003", title: "Req 3", requirement_type: "interface")
          ].join("\n")
        )
      end

      it "imports all requirements" do
        result = importer.import(xml)
        expect(result[:imported_requirements]).to eq(3)
        expect(project.requirements.reload.count).to eq(3)
      end

      it "preserves distinct UIDs" do
        importer.import(xml)
        uids = project.requirements.reload.pluck(:uid)
        expect(uids).to contain_exactly("EXT-0001", "EXT-0002", "EXT-0003")
      end
    end

    context "with hierarchy-based module/section structure" do
      let(:xml) do
        build_reqif_xml(
          spec_objects: [
            spec_object(id: "so-1", uid: "EXT-0001", title: "Safety Req"),
            spec_object(id: "so-2", uid: "EXT-0002", title: "SW Req")
          ].join("\n"),
          hierarchy: [
            hierarchy_module(name: "Safety Module", children:
              hierarchy_section(name: "Hazard Analysis", children:
                hierarchy_req(ref: "so-1")
              )
            ),
            hierarchy_module(name: "Software Module", children:
              hierarchy_section(name: "Architecture", children:
                hierarchy_req(ref: "so-2")
              )
            )
          ].join("\n")
        )
      end

      it "creates modules from hierarchy" do
        importer.import(xml)
        module_names = project.requirement_modules.reload.pluck(:name).sort
        expect(module_names).to eq(["Safety Module", "Software Module"])
      end

      it "creates sections from hierarchy" do
        importer.import(xml)
        section_names = Section.joins(:requirement_module)
          .where(requirement_modules: { project_id: project.id })
          .pluck(:name).sort
        expect(section_names).to eq(["Architecture", "Hazard Analysis"])
      end

      it "assigns requirements to correct sections" do
        importer.import(xml)
        safety_req = project.requirements.reload.find_by(uid: "EXT-0001")
        expect(safety_req.section.name).to eq("Hazard Analysis")
        expect(safety_req.section.requirement_module.name).to eq("Safety Module")
      end
    end

    context "with module/section from spec object attributes" do
      let(:xml) do
        build_reqif_xml(
          spec_objects: spec_object(
            id: "so-1", uid: "EXT-0001", title: "Req with attrs",
            module_name: "Attr Module", section_name: "Attr Section"
          )
        )
      end

      it "uses module_name and section_name attributes when no hierarchy" do
        importer.import(xml)
        req = project.requirements.reload.first
        expect(req.section.requirement_module.name).to eq("Attr Module")
        expect(req.section.name).to eq("Attr Section")
      end
    end

    context "with traceability links" do
      let(:xml) do
        build_reqif_xml(
          spec_objects: [
            spec_object(id: "so-1", uid: "EXT-0001", title: "System Req"),
            spec_object(id: "so-2", uid: "EXT-0002", title: "SW Req")
          ].join("\n"),
          spec_relations: spec_relation(
            id: "sr-1", source_ref: "so-1", target_ref: "so-2",
            link_type: "derives_from", description: "System to SW derivation"
          )
        )
      end

      it "imports the traceability link" do
        result = importer.import(xml)
        expect(result[:imported_links]).to eq(1)
      end

      it "sets link attributes correctly" do
        importer.import(xml)
        link = TraceabilityLink.last
        expect(link.link_type).to eq("derives_from")
        expect(link.description).to eq("System to SW derivation")
        expect(link.source_requirement.uid).to eq("EXT-0001")
        expect(link.target_requirement.uid).to eq("EXT-0002")
        expect(link.created_by).to eq(user)
      end
    end

    context "with multiple link types" do
      let(:xml) do
        build_reqif_xml(
          spec_objects: [
            spec_object(id: "so-1", uid: "EXT-0001", title: "Req A"),
            spec_object(id: "so-2", uid: "EXT-0002", title: "Req B"),
            spec_object(id: "so-3", uid: "EXT-0003", title: "Req C")
          ].join("\n"),
          spec_relations: [
            spec_relation(id: "sr-1", source_ref: "so-1", target_ref: "so-2", link_type: "derives_from"),
            spec_relation(id: "sr-2", source_ref: "so-2", target_ref: "so-3", link_type: "satisfies"),
            spec_relation(id: "sr-3", source_ref: "so-1", target_ref: "so-3", link_type: "verifies")
          ].join("\n")
        )
      end

      it "imports all links" do
        result = importer.import(xml)
        expect(result[:imported_links]).to eq(3)
      end

      it "preserves link types" do
        importer.import(xml)
        link_types = TraceabilityLink.pluck(:link_type).sort
        expect(link_types).to eq(%w[derives_from satisfies verifies])
      end
    end

    context "with link to non-imported requirement" do
      let(:xml) do
        build_reqif_xml(
          spec_objects: spec_object(id: "so-1", uid: "EXT-0001", title: "Req"),
          spec_relations: spec_relation(
            id: "sr-1", source_ref: "so-1", target_ref: "so-missing", link_type: "derives_from"
          )
        )
      end

      it "records a link warning for the missing target" do
        result = importer.import(xml)
        expect(result[:link_warnings]).to include(hash_including(message: /Source or target requirement not found/))
      end

      it "still imports the valid requirement successfully" do
        result = importer.import(xml)
        expect(result[:imported_requirements]).to eq(1)
        expect(result[:success]).to be true
      end
    end

    context "with enum defaults" do
      let(:xml) do
        build_reqif_xml(
          spec_objects: spec_object(id: "so-1", uid: "EXT-0001", title: "Minimal req")
        )
      end

      it "defaults to functional, draft, must_have, qm" do
        importer.import(xml)
        req = project.requirements.reload.first
        expect(req.requirement_type).to eq("functional")
        expect(req.status).to eq("draft")
        expect(req.priority).to eq("must_have")
        expect(req.asil_level).to eq("qm")
      end
    end

    context "with nil body" do
      let(:xml) do
        build_reqif_xml(
          spec_objects: spec_object(id: "so-1", uid: "EXT-0001", title: "No body req")
        )
      end

      it "imports with nil body" do
        importer.import(xml)
        req = project.requirements.reload.first
        expect(req.body).to be_nil
      end
    end

    context "with blank title" do
      let(:xml) do
        build_reqif_xml(
          spec_objects: spec_object(id: "so-1", uid: "EXT-0001", title: "").gsub('THE-VALUE=""', 'THE-VALUE=""')
        )
      end

      it "reports a validation error" do
        # Build XML with explicitly blank title
        blank_xml = build_reqif_xml(
          spec_objects: %(<SPEC-OBJECT IDENTIFIER="so-1" LONG-NAME="blank" LAST-CHANGE="2026-01-01T00:00:00Z">
            <VALUES>
              <ATTRIBUTE-VALUE-STRING THE-VALUE=""><DEFINITION><ATTRIBUTE-DEFINITION-STRING-REF>ad-title</ATTRIBUTE-DEFINITION-STRING-REF></DEFINITION></ATTRIBUTE-VALUE-STRING>
            </VALUES>
            <TYPE><SPEC-OBJECT-TYPE-REF>sot-requirement</SPEC-OBJECT-TYPE-REF></TYPE>
          </SPEC-OBJECT>)
        )
        result = importer.import(blank_xml)
        expect(result[:success]).to be false
        expect(result[:errors]).not_to be_empty
      end
    end

    context "with empty spec objects" do
      let(:xml) { build_reqif_xml(spec_objects: "") }

      it "raises a validation error" do
        expect { importer.import(xml) }.to raise_error(
          ReqifImporter::ValidationError, /no requirements/
        )
      end
    end

    context "with duplicate UID in import" do
      let(:xml) do
        build_reqif_xml(
          spec_objects: [
            spec_object(id: "so-1", uid: "DUP-0001", title: "First"),
            spec_object(id: "so-2", uid: "DUP-0001", title: "Duplicate")
          ].join("\n")
        )
      end

      it "reports an error and rolls back" do
        result = importer.import(xml)
        expect(result[:success]).to be false
        expect(result[:imported_requirements]).to eq(0)
        expect(project.requirements.reload.count).to eq(0)
      end
    end

    context "with duplicate UID against existing requirements" do
      before do
        mod = project.requirement_modules.create!(name: "Existing")
        sec = mod.sections.create!(name: "Default")
        sec.requirements.create!(
          project: project, uid: "IMP-0001", title: "Existing",
          created_by: user
        )
      end

      let(:xml) do
        build_reqif_xml(
          spec_objects: spec_object(id: "so-1", uid: "IMP-0001", title: "Conflict")
        )
      end

      it "reports an error for duplicate UID" do
        result = importer.import(xml)
        expect(result[:success]).to be false
        expect(result[:errors].first[:message]).to match(/uid/i)
      end
    end

    context "with section reuse" do
      let(:xml) do
        build_reqif_xml(
          spec_objects: [
            spec_object(id: "so-1", uid: "EXT-0001", title: "Req A",
                       module_name: "Safety", section_name: "Hazards"),
            spec_object(id: "so-2", uid: "EXT-0002", title: "Req B",
                       module_name: "Safety", section_name: "Hazards")
          ].join("\n")
        )
      end

      it "reuses the same module and section" do
        importer.import(xml)
        expect(project.requirement_modules.reload.count).to eq(1)
        expect(Section.count).to eq(1)
        expect(project.requirements.reload.count).to eq(2)
      end
    end

    context "with invalid XML" do
      it "raises a parse error" do
        expect { importer.import("not xml at all <<<") }.to raise_error(ReqifImporter::ParseError)
      end
    end

    context "with missing REQ-IF root element" do
      it "raises a validation error" do
        xml = '<?xml version="1.0"?><WRONG-ROOT/>'
        expect { importer.import(xml) }.to raise_error(
          ReqifImporter::ValidationError, /missing REQ-IF root element/
        )
      end
    end

    context "with link description" do
      let(:xml) do
        build_reqif_xml(
          spec_objects: [
            spec_object(id: "so-1", uid: "EXT-0001", title: "Req A"),
            spec_object(id: "so-2", uid: "EXT-0002", title: "Req B")
          ].join("\n"),
          spec_relations: spec_relation(
            id: "sr-1", source_ref: "so-1", target_ref: "so-2",
            link_type: "satisfies", description: "Req B satisfies Req A"
          )
        )
      end

      it "preserves link descriptions" do
        importer.import(xml)
        link = TraceabilityLink.last
        expect(link.description).to eq("Req B satisfies Req A")
      end
    end

    context "with transaction rollback" do
      let(:xml) do
        # First req is valid, second has blank title → both should be rolled back
        blank_title_obj = %(<SPEC-OBJECT IDENTIFIER="so-2" LONG-NAME="blank" LAST-CHANGE="2026-01-01T00:00:00Z">
          <VALUES>
            <ATTRIBUTE-VALUE-STRING THE-VALUE=""><DEFINITION><ATTRIBUTE-DEFINITION-STRING-REF>ad-title</ATTRIBUTE-DEFINITION-STRING-REF></DEFINITION></ATTRIBUTE-VALUE-STRING>
          </VALUES>
          <TYPE><SPEC-OBJECT-TYPE-REF>sot-requirement</SPEC-OBJECT-TYPE-REF></TYPE>
        </SPEC-OBJECT>)

        build_reqif_xml(
          spec_objects: [
            spec_object(id: "so-1", uid: "EXT-0001", title: "Valid Req"),
            blank_title_obj
          ].join("\n")
        )
      end

      it "rolls back all requirements on error" do
        result = importer.import(xml)
        expect(result[:success]).to be false
        expect(result[:imported_requirements]).to eq(0)
        expect(project.requirements.reload.count).to eq(0)
      end
    end
  end

  describe "#import_file" do
    it "reads from file and imports" do
      xml = build_reqif_xml(
        spec_objects: spec_object(id: "so-1", uid: "EXT-0001", title: "File Req", body: "From file")
      )

      file = Tempfile.new(["test", ".reqif"])
      begin
        file.write(xml)
        file.close

        result = importer.import_file(file.path)
        expect(result[:success]).to be true
        expect(result[:imported_requirements]).to eq(1)
        expect(project.requirements.reload.first.title).to eq("File Req")
      ensure
        file.unlink
      end
    end
  end

  describe "round-trip with ReqifExporter" do
    let(:source_project) { create(:project, organization: organization, prefix: "SRC") }
    let(:target_project) { create(:project, organization: organization, prefix: "TGT") }

    before do
      mod = source_project.requirement_modules.create!(name: "System Requirements")
      sec = mod.sections.create!(name: "Functional")

      @req1 = sec.requirements.create!(
        project: source_project, uid: "SRC-0001", title: "Braking shall stop vehicle",
        body: "The braking system shall bring the vehicle to a complete stop within 50m at 100km/h.",
        requirement_type: "safety", status: "approved", priority: "must_have",
        asil_level: "asil_d", created_by: user
      )
      @req2 = sec.requirements.create!(
        project: source_project, uid: "SRC-0002", title: "ABS control module",
        body: "The ABS module shall modulate brake pressure at 15Hz.",
        requirement_type: "functional", status: "draft", priority: "should_have",
        asil_level: "asil_b", created_by: user
      )
      TraceabilityLink.create!(
        source_requirement: @req1, target_requirement: @req2,
        link_type: "derives_from", description: "System to SW derivation",
        created_by: user
      )
    end

    it "preserves requirement attributes through export/import" do
      xml = export_project(source_project)
      # Destroy source requirements to avoid global UID uniqueness conflicts
      source_project.requirements.destroy_all
      target_importer = described_class.new(target_project, user)
      result = target_importer.import(xml)

      expect(result[:success]).to be true
      expect(result[:imported_requirements]).to eq(2)

      imported_req = target_project.requirements.reload.find_by(uid: "SRC-0001")
      expect(imported_req).to be_present
      expect(imported_req.title).to eq("Braking shall stop vehicle")
      expect(imported_req.requirement_type).to eq("safety")
      expect(imported_req.status).to eq("approved")
      expect(imported_req.priority).to eq("must_have")
      expect(imported_req.asil_level).to eq("asil_d")
    end

    it "preserves traceability links through export/import" do
      xml = export_project(source_project)
      source_project.requirements.destroy_all
      target_importer = described_class.new(target_project, user)
      result = target_importer.import(xml)

      expect(result[:imported_links]).to eq(1)
      link = TraceabilityLink.where(
        source_requirement: target_project.requirements,
        target_requirement: target_project.requirements
      ).first
      expect(link.link_type).to eq("derives_from")
      expect(link.description).to eq("System to SW derivation")
    end

    it "preserves module/section hierarchy through export/import" do
      xml = export_project(source_project)
      source_project.requirements.destroy_all
      target_importer = described_class.new(target_project, user)
      target_importer.import(xml)

      mod = target_project.requirement_modules.reload.find_by(name: "System Requirements")
      expect(mod).to be_present

      sec = mod.sections.find_by(name: "Functional")
      expect(sec).to be_present
      expect(sec.requirements.count).to eq(2)
    end
  end

  describe "constants" do
    it "has valid requirement types matching Requirement model" do
      expect(described_class::VALID_REQUIREMENT_TYPES).to eq(Requirement.requirement_types.keys)
    end

    it "has valid statuses matching Requirement model" do
      expect(described_class::VALID_STATUSES).to eq(Requirement.statuses.keys)
    end

    it "has valid priorities matching Requirement model" do
      expect(described_class::VALID_PRIORITIES).to eq(Requirement.priorities.keys)
    end

    it "has valid ASIL levels matching Requirement model" do
      expect(described_class::VALID_ASIL_LEVELS).to eq(Requirement.asil_levels.keys)
    end

    it "has valid link types matching TraceabilityLink model" do
      expect(described_class::VALID_LINK_TYPES).to eq(TraceabilityLink.link_types.keys)
    end
  end
end
