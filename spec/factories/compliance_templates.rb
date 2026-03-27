FactoryBot.define do
  factory :compliance_template do
    sequence(:name) { |n| "Template #{n}" }
    standard { "iso_26262" }
    description { "A test compliance template" }
    template_data do
      {
        attribute_schema: [
          { name: "Test Attr", type: "text", required: false }
        ],
        modules: [
          {
            key: "mod_a",
            name: "Module A",
            description: "First module",
            sections: [
              { name: "Section A1" },
              { name: "Section A2" }
            ]
          },
          {
            key: "mod_b",
            name: "Module B",
            description: "Second module",
            sections: [
              { name: "Section B1" }
            ]
          }
        ],
        expected_links: [
          { source_module: "mod_a", target_module: "mod_b", link_type: "derives_from", description: "B derives from A" }
        ]
      }
    end
    active { true }

    trait :inactive do
      active { false }
    end

    trait :iso_26262 do
      name { "ISO 26262 — Functional Safety" }
      standard { "iso_26262" }
      description { "ISO 26262 V-model template for automotive functional safety." }
      template_data { ComplianceTemplate.iso_26262_template_data }
    end

    trait :aspice do
      name { "Automotive SPICE (ASPICE)" }
      standard { "aspice" }
      description { "Automotive SPICE process assessment model template." }
      template_data { ComplianceTemplate.aspice_template_data }
    end
  end
end
