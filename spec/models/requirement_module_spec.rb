require 'rails_helper'

RSpec.describe RequirementModule, type: :model do
  describe "factory" do
    it "has a valid factory" do
      expect(build(:requirement_module)).to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
    pending "has_many sections (Section model not yet generated)"
  end

  describe "validations" do
    subject { build(:requirement_module) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:project_id) }

    it "allows the same module name in different projects" do
      org = create(:organization)
      project_a = create(:project, organization: org)
      project_b = create(:project, organization: org)

      create(:requirement_module, project: project_a, name: "System Requirements")
      mod_b = build(:requirement_module, project: project_b, name: "System Requirements")

      expect(mod_b).to be_valid
    end
  end

  describe "acts_as_list" do
    let(:project) { create(:project) }

    it "auto-assigns position on creation" do
      mod1 = create(:requirement_module, project: project, name: "First")
      mod2 = create(:requirement_module, project: project, name: "Second")

      expect(mod1.position).to eq(1)
      expect(mod2.position).to eq(2)
    end

    it "scopes position to project" do
      org = create(:organization)
      project_a = create(:project, organization: org)
      project_b = create(:project, organization: org)

      create(:requirement_module, project: project_a, name: "Module A1")
      create(:requirement_module, project: project_a, name: "Module A2")
      mod_b1 = create(:requirement_module, project: project_b, name: "Module B1")

      expect(mod_b1.position).to eq(1)
    end

    it "supports reordering" do
      mod1 = create(:requirement_module, project: project, name: "First")
      mod2 = create(:requirement_module, project: project, name: "Second")
      mod3 = create(:requirement_module, project: project, name: "Third")

      mod3.insert_at(1)

      expect(mod3.reload.position).to eq(1)
      expect(mod1.reload.position).to eq(2)
      expect(mod2.reload.position).to eq(3)
    end
  end
end
