require 'rails_helper'

RSpec.describe Section, type: :model do
  describe "factory" do
    it "has a valid factory" do
      expect(build(:section)).to be_valid
    end

    it "has a valid nested factory" do
      expect(build(:section, :nested)).to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:requirement_module) }
    it { is_expected.to belong_to(:parent_section).class_name("Section").optional }
    it { is_expected.to have_many(:child_sections).class_name("Section").dependent(:destroy) }
    it { is_expected.to have_many(:requirements).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:section) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to([:requirement_module_id, :parent_section_id]) }

    it "allows the same section name under different parent sections" do
      mod = create(:requirement_module)
      parent_a = create(:section, requirement_module: mod, name: "Parent A")
      parent_b = create(:section, requirement_module: mod, name: "Parent B")

      create(:section, requirement_module: mod, parent_section: parent_a, name: "Details")
      section_b = build(:section, requirement_module: mod, parent_section: parent_b, name: "Details")

      expect(section_b).to be_valid
    end

    it "allows the same section name in different modules" do
      project = create(:project)
      mod_a = create(:requirement_module, project: project, name: "Module A")
      mod_b = create(:requirement_module, project: project, name: "Module B")

      create(:section, requirement_module: mod_a, name: "Overview")
      section_b = build(:section, requirement_module: mod_b, name: "Overview")

      expect(section_b).to be_valid
    end

    it "rejects duplicate names under the same parent within the same module" do
      mod = create(:requirement_module)
      parent = create(:section, requirement_module: mod, name: "Parent")

      create(:section, requirement_module: mod, parent_section: parent, name: "Duplicate")
      section = build(:section, requirement_module: mod, parent_section: parent, name: "Duplicate")

      expect(section).not_to be_valid
      expect(section.errors[:name]).to include("has already been taken")
    end
  end

  describe "self-referential hierarchy" do
    let(:mod) { create(:requirement_module) }

    it "supports nested sections" do
      parent = create(:section, requirement_module: mod, name: "Parent")
      child = create(:section, requirement_module: mod, parent_section: parent, name: "Child")

      expect(parent.child_sections).to include(child)
      expect(child.parent_section).to eq(parent)
    end

    it "supports deeply nested sections" do
      grandparent = create(:section, requirement_module: mod, name: "Level 1")
      parent = create(:section, requirement_module: mod, parent_section: grandparent, name: "Level 2")
      child = create(:section, requirement_module: mod, parent_section: parent, name: "Level 3")

      expect(grandparent.child_sections).to include(parent)
      expect(parent.child_sections).to include(child)
      expect(child.parent_section.parent_section).to eq(grandparent)
    end

    it "cascades destruction to child sections" do
      parent = create(:section, requirement_module: mod, name: "Parent")
      create(:section, requirement_module: mod, parent_section: parent, name: "Child 1")
      create(:section, requirement_module: mod, parent_section: parent, name: "Child 2")

      expect { parent.destroy }.to change(Section, :count).by(-3)
    end
  end

  describe "acts_as_list" do
    let(:mod) { create(:requirement_module) }

    it "auto-assigns position on creation" do
      sec1 = create(:section, requirement_module: mod, name: "First")
      sec2 = create(:section, requirement_module: mod, name: "Second")

      expect(sec1.position).to eq(1)
      expect(sec2.position).to eq(2)
    end

    it "scopes position to requirement_module and parent_section" do
      parent_a = create(:section, requirement_module: mod, name: "Parent A")
      parent_b = create(:section, requirement_module: mod, name: "Parent B")

      create(:section, requirement_module: mod, parent_section: parent_a, name: "Child A1")
      create(:section, requirement_module: mod, parent_section: parent_a, name: "Child A2")
      child_b1 = create(:section, requirement_module: mod, parent_section: parent_b, name: "Child B1")

      expect(child_b1.position).to eq(1)
    end

    it "supports reordering within the same scope" do
      sec1 = create(:section, requirement_module: mod, name: "First")
      sec2 = create(:section, requirement_module: mod, name: "Second")
      sec3 = create(:section, requirement_module: mod, name: "Third")

      sec3.insert_at(1)

      expect(sec3.reload.position).to eq(1)
      expect(sec1.reload.position).to eq(2)
      expect(sec2.reload.position).to eq(3)
    end

    it "maintains independent ordering per module" do
      project = create(:project)
      mod_a = create(:requirement_module, project: project, name: "Module A")
      mod_b = create(:requirement_module, project: project, name: "Module B")

      create(:section, requirement_module: mod_a, name: "A1")
      create(:section, requirement_module: mod_a, name: "A2")
      sec_b1 = create(:section, requirement_module: mod_b, name: "B1")

      expect(sec_b1.position).to eq(1)
    end
  end
end
