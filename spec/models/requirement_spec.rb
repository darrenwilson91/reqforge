require 'rails_helper'

RSpec.describe Requirement, type: :model do
  describe "factory" do
    it "has a valid factory" do
      expect(build(:requirement)).to be_valid
    end

    it "persists a requirement" do
      requirement = create(:requirement)
      expect(requirement).to be_persisted
    end

    it "creates a safety requirement" do
      requirement = create(:requirement, :safety)
      expect(requirement).to be_safety
      expect(requirement).to be_asil_b
    end

    it "creates an approved requirement" do
      requirement = create(:requirement, :approved)
      expect(requirement).to be_approved
    end

    it "creates a requirement with custom attributes" do
      requirement = create(:requirement, :with_custom_attributes)
      expect(requirement.custom_attributes["Safety Classification"]).to eq("ASIL-B")
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:section) }
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:created_by).class_name("User") }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }

    it "requires uid presence (tested without auto-generation)" do
      req = build(:requirement)
      req.uid = nil
      req.valid? # triggers generate_uid callback
      # After callback, uid should be filled — test that a blank project prefix scenario fails
      req2 = Requirement.new(title: "Test", section: req.section, project: nil)
      req2.uid = ""
      expect(req2).not_to be_valid
      expect(req2.errors[:uid]).to include("can't be blank")
    end

    it "enforces uid uniqueness" do
      existing = create(:requirement)
      duplicate = build(:requirement, uid: existing.uid)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:uid]).to include("has already been taken")
    end
  end

  describe "enums" do
    it do
      is_expected.to define_enum_for(:requirement_type).with_values(
        functional: 0, non_functional: 1, safety: 2, interface: 3, design_constraint: 4
      )
    end

    it do
      is_expected.to define_enum_for(:status).with_values(
        draft: 0, in_review: 1, approved: 2, implemented: 3, verified: 4, obsolete: 5
      )
    end

    it do
      is_expected.to define_enum_for(:priority).with_values(
        must_have: 0, should_have: 1, could_have: 2, wont_have: 3
      )
    end

    it do
      is_expected.to define_enum_for(:asil_level).with_values(
        qm: 0, asil_a: 1, asil_b: 2, asil_c: 3, asil_d: 4
      )
    end
  end

  describe "UID generation" do
    let(:project) { create(:project, prefix: "SWR") }
    let(:mod) { create(:requirement_module, project: project) }
    let(:section) { create(:section, requirement_module: mod) }
    let(:user) { create(:user) }

    it "auto-generates UID from project prefix and sequence" do
      req = create(:requirement, section: section, project: project, created_by: user)
      expect(req.uid).to eq("SWR-0001")
    end

    it "increments the sequence for subsequent requirements" do
      create(:requirement, section: section, project: project, created_by: user)
      req2 = create(:requirement, section: section, project: project, created_by: user)
      expect(req2.uid).to eq("SWR-0002")
    end

    it "does not overwrite an explicitly provided UID" do
      req = create(:requirement, section: section, project: project, created_by: user, uid: "CUSTOM-001")
      expect(req.uid).to eq("CUSTOM-001")
    end

    it "generates independent sequences per project" do
      project2 = create(:project, prefix: "HWR", organization: project.organization)
      mod2 = create(:requirement_module, project: project2)
      section2 = create(:section, requirement_module: mod2)

      create(:requirement, section: section, project: project, created_by: user)
      req2 = create(:requirement, section: section2, project: project2, created_by: user)

      expect(req2.uid).to eq("HWR-0001")
    end
  end

  describe "acts_as_list" do
    let(:section) { create(:section) }
    let(:project) { section.requirement_module.project }
    let(:user) { create(:user) }

    it "auto-assigns position on creation" do
      req1 = create(:requirement, section: section, project: project, created_by: user)
      req2 = create(:requirement, section: section, project: project, created_by: user)

      expect(req1.position).to eq(1)
      expect(req2.position).to eq(2)
    end

    it "scopes position to section" do
      section2 = create(:section, requirement_module: section.requirement_module, name: "Other Section")

      create(:requirement, section: section, project: project, created_by: user)
      create(:requirement, section: section, project: project, created_by: user)
      req_other = create(:requirement, section: section2, project: project, created_by: user)

      expect(req_other.position).to eq(1)
    end

    it "supports reordering within the same section" do
      req1 = create(:requirement, section: section, project: project, created_by: user)
      req2 = create(:requirement, section: section, project: project, created_by: user)
      req3 = create(:requirement, section: section, project: project, created_by: user)

      req3.insert_at(1)

      expect(req3.reload.position).to eq(1)
      expect(req1.reload.position).to eq(2)
      expect(req2.reload.position).to eq(3)
    end
  end

  describe "paper_trail" do
    it "tracks changes to requirements" do
      requirement = create(:requirement)
      expect(requirement.versions.count).to eq(1)

      requirement.update!(title: "Updated Title")
      expect(requirement.versions.count).to eq(2)
    end

    it "can revert to a previous version" do
      requirement = create(:requirement, title: "Original")
      requirement.update!(title: "Changed")

      previous = requirement.versions.last.reify
      expect(previous.title).to eq("Original")
    end
  end

  describe "custom_attributes" do
    it "defaults to an empty hash" do
      requirement = create(:requirement)
      expect(requirement.custom_attributes).to eq({})
    end

    it "stores arbitrary key-value pairs" do
      requirement = create(:requirement, custom_attributes: { "Weight" => "2.5kg", "Material" => "Steel" })
      requirement.reload
      expect(requirement.custom_attributes["Weight"]).to eq("2.5kg")
      expect(requirement.custom_attributes["Material"]).to eq("Steel")
    end
  end

  describe "pg_search" do
    let(:project) { create(:project, prefix: "SRC") }
    let(:mod) { create(:requirement_module, project: project) }
    let(:section) { create(:section, requirement_module: mod) }
    let(:user) { create(:user) }

    let!(:req_braking) do
      create(:requirement,
        section: section, project: project, created_by: user,
        title: "Braking System Response Time",
        body: "The braking system shall respond within 100 milliseconds of pedal activation.")
    end

    let!(:req_steering) do
      create(:requirement,
        section: section, project: project, created_by: user,
        title: "Steering Torque Limit",
        body: "The electronic power steering shall limit assist torque to 50 Nm.")
    end

    let!(:req_engine) do
      create(:requirement,
        section: section, project: project, created_by: user,
        title: "Engine Idle Speed",
        body: "The engine control unit shall maintain idle speed at 750 RPM under normal conditions.")
    end

    describe ".search_by_text" do
      it "finds requirements matching title" do
        results = Requirement.search_by_text("braking")
        expect(results).to include(req_braking)
        expect(results).not_to include(req_steering, req_engine)
      end

      it "finds requirements matching body content" do
        results = Requirement.search_by_text("torque")
        expect(results).to include(req_steering)
        expect(results).not_to include(req_braking, req_engine)
      end

      it "finds requirements by UID" do
        results = Requirement.search_by_text(req_engine.uid)
        expect(results).to include(req_engine)
      end

      it "supports prefix matching" do
        results = Requirement.search_by_text("brak")
        expect(results).to include(req_braking)
      end

      it "returns empty when no match" do
        results = Requirement.search_by_text("nonexistent_xyz_term")
        expect(results).to be_empty
      end
    end

    describe "multisearchable" do
      it "creates pg_search_document records" do
        expect(PgSearch::Document.where(searchable: req_braking)).to exist
      end

      it "finds requirements via PgSearch.multisearch" do
        results = PgSearch.multisearch("braking")
        expect(results.map(&:searchable)).to include(req_braking)
      end

      it "updates search document when requirement changes" do
        req_braking.update!(title: "Acceleration System Response Time")
        results = PgSearch.multisearch("acceleration")
        expect(results.map(&:searchable)).to include(req_braking)
      end

      it "removes search document when requirement is destroyed" do
        req_braking.destroy!
        expect(PgSearch::Document.where(searchable_type: "Requirement", searchable_id: req_braking.id)).not_to exist
      end
    end
  end

  describe "default values" do
    it "defaults requirement_type to functional" do
      expect(Requirement.new.requirement_type).to eq("functional")
    end

    it "defaults status to draft" do
      expect(Requirement.new.status).to eq("draft")
    end

    it "defaults priority to must_have" do
      expect(Requirement.new.priority).to eq("must_have")
    end

    it "defaults asil_level to qm" do
      expect(Requirement.new.asil_level).to eq("qm")
    end
  end
end
