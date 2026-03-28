require 'rails_helper'

RSpec.describe TestCase, type: :model do
  describe "factory" do
    it "has a valid factory" do
      expect(build(:test_case)).to be_valid
    end

    it "has valid trait factories" do
      %i[integration system acceptance safety draft ready passed failed blocked without_requirement].each do |trait|
        expect(build(:test_case, trait)).to be_valid
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:requirement).optional }
    it { is_expected.to belong_to(:created_by).class_name("User") }
  end

  describe "validations" do
    subject { create(:test_case) }

    it { is_expected.to validate_presence_of(:uid) }
    it { is_expected.to validate_uniqueness_of(:uid) }
    it { is_expected.to validate_presence_of(:title) }
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:test_type).with_values(
        unit: 0, integration: 1, system: 2, acceptance: 3, safety: 4
      )
    }

    it {
      is_expected.to define_enum_for(:status).with_values(
        draft: 0, ready: 1, passed: 2, failed: 3, blocked: 4, not_run: 5
      )
    }

    it {
      is_expected.to define_enum_for(:priority).with_values(
        must_have: 0, should_have: 1, could_have: 2, wont_have: 3
      )
    }
  end

  describe "defaults" do
    let(:test_case) { create(:test_case) }

    it "defaults status to not_run" do
      tc = TestCase.new
      expect(tc.status).to eq("not_run")
    end

    it "defaults test_type to unit" do
      tc = TestCase.new
      expect(tc.test_type).to eq("unit")
    end

    it "defaults priority to must_have" do
      tc = TestCase.new
      expect(tc.priority).to eq("must_have")
    end
  end

  describe "UID generation" do
    let(:project) { create(:project, prefix: "BRK") }
    let(:section) { create(:section, requirement_module: create(:requirement_module, project: project)) }
    let(:user) { create(:user) }

    it "auto-generates UID with project prefix + TC + sequence" do
      tc = create(:test_case, project: project, created_by: user, uid: nil)
      expect(tc.uid).to eq("BRK-TC-001")
    end

    it "increments UID sequentially" do
      create(:test_case, project: project, created_by: user, uid: nil)
      tc2 = create(:test_case, project: project, created_by: user, uid: nil)
      expect(tc2.uid).to eq("BRK-TC-002")
    end

    it "does not overwrite an explicit UID" do
      tc = create(:test_case, project: project, created_by: user, uid: "CUSTOM-TC-999")
      expect(tc.uid).to eq("CUSTOM-TC-999")
    end

    it "generates UIDs independently per project" do
      project2 = create(:project, prefix: "ENG", organization: project.organization)
      tc1 = create(:test_case, project: project, created_by: user, uid: nil)
      tc2 = create(:test_case, project: project2, created_by: user, uid: nil)
      expect(tc1.uid).to eq("BRK-TC-001")
      expect(tc2.uid).to eq("ENG-TC-001")
    end

    it "uses 3-digit zero-padding" do
      tc = create(:test_case, project: project, created_by: user, uid: nil)
      expect(tc.uid).to match(/\ABRK-TC-\d{3}\z/)
    end
  end

  describe "paper_trail" do
    it "tracks creation" do
      tc = create(:test_case)
      expect(tc.versions.count).to eq(1)
      expect(tc.versions.last.event).to eq("create")
    end

    it "tracks updates" do
      tc = create(:test_case)
      tc.update!(title: "Updated title")
      expect(tc.versions.count).to eq(2)
      expect(tc.versions.last.event).to eq("update")
    end

    it "can revert to previous version" do
      tc = create(:test_case, title: "Original")
      tc.update!(title: "Changed")
      tc.paper_trail.previous_version.save!
      expect(tc.reload.title).to eq("Original")
    end
  end

  describe "optional requirement" do
    it "can be created without a requirement" do
      tc = create(:test_case, :without_requirement)
      expect(tc.requirement).to be_nil
      expect(tc).to be_persisted
    end

    it "can be linked to a requirement" do
      tc = create(:test_case)
      expect(tc.requirement).to be_present
    end
  end

  describe "project association" do
    it "can access test cases from project" do
      project = create(:project)
      tc = create(:test_case, project: project)
      expect(project.test_cases).to include(tc)
    end

    it "destroys test cases when project is destroyed" do
      project = create(:project)
      create(:test_case, project: project)
      expect { project.destroy }.to change(TestCase, :count).by(-1)
    end
  end

  describe "requirement association" do
    it "can access test cases from requirement" do
      requirement = create(:requirement)
      tc = create(:test_case, project: requirement.project, requirement: requirement)
      expect(requirement.test_cases).to include(tc)
    end

    it "nullifies test case when requirement is destroyed" do
      requirement = create(:requirement)
      tc = create(:test_case, project: requirement.project, requirement: requirement)
      requirement.destroy
      expect(tc.reload.requirement_id).to be_nil
    end
  end
end
