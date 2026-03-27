class ComplianceTemplate < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :standard, presence: true
  validates :template_data, presence: true

  scope :active, -> { where(active: true) }
  scope :for_standard, ->(standard) { where(standard: standard) }

  STANDARDS = %w[iso_26262 aspice].freeze

  # Applies this template to a project: creates modules, sections, and sets attribute_schema
  def apply_to_project!(project)
    data = template_data.deep_symbolize_keys

    if data[:attribute_schema].present?
      project.update!(attribute_schema: data[:attribute_schema])
    end

    module_map = {}

    (data[:modules] || []).each_with_index do |mod_data, mod_idx|
      req_module = project.requirement_modules.create!(
        name: mod_data[:name],
        position: mod_idx + 1
      )
      module_map[mod_data[:key]] = req_module if mod_data[:key].present?

      (mod_data[:sections] || []).each_with_index do |sec_data, sec_idx|
        req_module.sections.create!(
          name: sec_data[:name],
          position: sec_idx + 1
        )
      end
    end

    module_map
  end

  # Returns the expected traceability link types between modules for compliance checking
  def expected_links
    data = template_data.deep_symbolize_keys
    data[:expected_links] || []
  end

  # Returns the compliance phases for dashboard display
  def phases
    data = template_data.deep_symbolize_keys
    data[:modules]&.map { |m| { key: m[:key], name: m[:name], description: m[:description] } } || []
  end

  # --- Template Definitions ---

  def self.iso_26262_template_data
    {
      attribute_schema: [
        { name: "Safety Goal", type: "text", required: false },
        { name: "ASIL Allocation", type: "enum", required: false, options: "QM,ASIL-A,ASIL-B,ASIL-C,ASIL-D" },
        { name: "Verification Method", type: "enum", required: false, options: "Review,Analysis,Simulation,Testing" },
        { name: "Compliance Reference", type: "text", required: false }
      ],
      modules: [
        {
          key: "sys_req",
          name: "System Requirements",
          description: "ISO 26262 Part 3 — Vehicle-level safety requirements derived from hazard analysis and risk assessment",
          sections: [
            { name: "Safety Goals" },
            { name: "Functional Safety Requirements" },
            { name: "Technical Safety Requirements" }
          ]
        },
        {
          key: "sw_req",
          name: "Software Requirements",
          description: "ISO 26262 Part 6 — Software safety requirements specification derived from system requirements",
          sections: [
            { name: "Software Safety Requirements" },
            { name: "Software Functional Requirements" },
            { name: "Software Interface Requirements" },
            { name: "Software Non-Functional Requirements" }
          ]
        },
        {
          key: "sw_arch",
          name: "Software Architecture",
          description: "ISO 26262 Part 6 — Software architectural design with safety mechanisms",
          sections: [
            { name: "Architectural Components" },
            { name: "Safety Mechanisms" },
            { name: "Interface Definitions" }
          ]
        },
        {
          key: "sw_design",
          name: "Software Detailed Design",
          description: "ISO 26262 Part 6 — Detailed design of software units and components",
          sections: [
            { name: "Unit Design Specifications" },
            { name: "Data Flow Definitions" }
          ]
        },
        {
          key: "unit_test",
          name: "Unit Test Specifications",
          description: "ISO 26262 Part 6 — Unit-level verification test specifications",
          sections: [
            { name: "Unit Test Cases" },
            { name: "Coverage Requirements" }
          ]
        },
        {
          key: "int_test",
          name: "Integration Test Specifications",
          description: "ISO 26262 Part 6 — Software integration test specifications",
          sections: [
            { name: "Integration Test Cases" },
            { name: "Interface Test Cases" }
          ]
        },
        {
          key: "sys_test",
          name: "System Test Specifications",
          description: "ISO 26262 Part 4 — System-level verification and validation test specifications",
          sections: [
            { name: "System Test Cases" },
            { name: "Safety Validation Cases" }
          ]
        }
      ],
      expected_links: [
        { source_module: "sys_req", target_module: "sw_req", link_type: "derives_from", description: "SW requirements derive from system requirements" },
        { source_module: "sw_req", target_module: "sw_arch", link_type: "satisfies", description: "Architecture satisfies SW requirements" },
        { source_module: "sw_arch", target_module: "sw_design", link_type: "refines", description: "Detailed design refines architecture" },
        { source_module: "sw_design", target_module: "unit_test", link_type: "verifies", description: "Unit tests verify detailed design" },
        { source_module: "sw_arch", target_module: "int_test", link_type: "verifies", description: "Integration tests verify architecture" },
        { source_module: "sys_req", target_module: "sys_test", link_type: "verifies", description: "System tests verify system requirements" }
      ]
    }
  end

  def self.aspice_template_data
    {
      attribute_schema: [
        { name: "Process Area", type: "enum", required: false, options: "SWE.1,SWE.2,SWE.3,SWE.4,SWE.5,SWE.6,SUP.7,SUP.9,SUP.10" },
        { name: "Capability Level", type: "enum", required: false, options: "0,1,2,3" },
        { name: "Work Product ID", type: "text", required: false },
        { name: "Compliance Reference", type: "text", required: false }
      ],
      modules: [
        {
          key: "swe1",
          name: "SWE.1 — Software Requirements Analysis",
          description: "ASPICE SWE.1 — Establish and maintain software requirements including interfaces",
          sections: [
            { name: "Functional Requirements" },
            { name: "Interface Requirements" },
            { name: "Non-Functional Requirements" },
            { name: "Resource Consumption Requirements" }
          ]
        },
        {
          key: "swe2",
          name: "SWE.2 — Software Architectural Design",
          description: "ASPICE SWE.2 — Establish software architectural design identifying software elements",
          sections: [
            { name: "Architectural Elements" },
            { name: "Interface Specifications" },
            { name: "Dynamic Behavior" },
            { name: "Resource Consumption Objectives" }
          ]
        },
        {
          key: "swe3",
          name: "SWE.3 — Software Detailed Design and Unit Construction",
          description: "ASPICE SWE.3 — Develop detailed design for each software component",
          sections: [
            { name: "Detailed Design Specifications" },
            { name: "Unit Specifications" },
            { name: "Interface Descriptions" }
          ]
        },
        {
          key: "swe4",
          name: "SWE.4 — Software Unit Verification",
          description: "ASPICE SWE.4 — Verify software units against detailed design and requirements",
          sections: [
            { name: "Unit Verification Criteria" },
            { name: "Unit Test Cases" },
            { name: "Static Analysis Requirements" }
          ]
        },
        {
          key: "swe5",
          name: "SWE.5 — Software Integration and Integration Test",
          description: "ASPICE SWE.5 — Integrate software units and test the integrated software",
          sections: [
            { name: "Integration Strategy" },
            { name: "Integration Test Cases" },
            { name: "Regression Test Cases" }
          ]
        },
        {
          key: "swe6",
          name: "SWE.6 — Software Qualification Test",
          description: "ASPICE SWE.6 — Ensure the integrated software meets the software requirements",
          sections: [
            { name: "Qualification Strategy" },
            { name: "Qualification Test Cases" },
            { name: "Acceptance Criteria" }
          ]
        },
        {
          key: "sup7",
          name: "SUP.7 — Documentation",
          description: "ASPICE SUP.7 — Develop and maintain documents recording information",
          sections: [
            { name: "Documentation Standards" },
            { name: "Document Templates" }
          ]
        },
        {
          key: "sup9",
          name: "SUP.9 — Problem Resolution Management",
          description: "ASPICE SUP.9 — Ensure problems are identified, analyzed, managed, and controlled",
          sections: [
            { name: "Problem Categories" },
            { name: "Resolution Procedures" }
          ]
        },
        {
          key: "sup10",
          name: "SUP.10 — Change Request Management",
          description: "ASPICE SUP.10 — Ensure change requests are managed, tracked, and controlled",
          sections: [
            { name: "Change Request Process" },
            { name: "Impact Assessment Criteria" }
          ]
        }
      ],
      expected_links: [
        { source_module: "swe1", target_module: "swe2", link_type: "derives_from", description: "Architecture derives from software requirements" },
        { source_module: "swe2", target_module: "swe3", link_type: "refines", description: "Detailed design refines architectural design" },
        { source_module: "swe3", target_module: "swe4", link_type: "verifies", description: "Unit verification verifies detailed design" },
        { source_module: "swe2", target_module: "swe5", link_type: "verifies", description: "Integration tests verify architectural design" },
        { source_module: "swe1", target_module: "swe6", link_type: "verifies", description: "Qualification tests verify software requirements" },
        { source_module: "swe1", target_module: "swe3", link_type: "implements", description: "Detailed design implements software requirements" }
      ]
    }
  end

  # Seeds the database with predefined compliance templates
  def self.seed_templates!
    find_or_create_by!(name: "ISO 26262 — Functional Safety") do |t|
      t.standard = "iso_26262"
      t.description = "ISO 26262 V-model template for automotive functional safety. Creates modules for each V-model phase from System Requirements through System Test Specifications, with predefined traceability link types between phases for full safety lifecycle coverage."
      t.template_data = iso_26262_template_data
      t.active = true
    end

    find_or_create_by!(name: "Automotive SPICE (ASPICE)") do |t|
      t.standard = "aspice"
      t.description = "Automotive SPICE process assessment model template. Creates modules aligned with SWE.1–SWE.6 software engineering processes and SUP.7/SUP.9/SUP.10 supporting processes, with traceability links mapping the V-model verification chain."
      t.template_data = aspice_template_data
      t.active = true
    end
  end
end
