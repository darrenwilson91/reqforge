require 'rails_helper'

RSpec.describe TraceabilityLink, type: :model do
  let(:project) { create(:project) }
  let(:section) { create(:section, requirement_module: create(:requirement_module, project: project)) }
  let(:user) { create(:user) }
  let(:req_a) { create(:requirement, project: project, section: section, created_by: user) }
  let(:req_b) { create(:requirement, project: project, section: section, created_by: user) }

  describe "factory" do
    it "creates a valid traceability link" do
      link = build(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user)
      expect(link).to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:source_requirement).class_name("Requirement") }
    it { is_expected.to belong_to(:target_requirement).class_name("Requirement") }
    it { is_expected.to belong_to(:created_by).class_name("User") }
  end

  describe "validations" do
    describe "no self-links" do
      it "rejects a link where source and target are the same requirement" do
        link = build(:traceability_link, source_requirement: req_a, target_requirement: req_a, created_by: user)
        expect(link).not_to be_valid
        expect(link.errors[:target_requirement_id]).to include("cannot be the same as source requirement")
      end
    end

    describe "uniqueness" do
      it "rejects duplicate links with same source, target, and link_type" do
        create(:traceability_link, source_requirement: req_a, target_requirement: req_b, link_type: :derives_from, created_by: user)
        duplicate = build(:traceability_link, source_requirement: req_a, target_requirement: req_b, link_type: :derives_from, created_by: user)
        expect(duplicate).not_to be_valid
      end

      it "allows same source and target with different link_type" do
        create(:traceability_link, source_requirement: req_a, target_requirement: req_b, link_type: :derives_from, created_by: user)
        different_type = build(:traceability_link, source_requirement: req_a, target_requirement: req_b, link_type: :verifies, created_by: user)
        expect(different_type).to be_valid
      end

      it "allows same link_type with different source" do
        req_c = create(:requirement, project: project, section: section, created_by: user)
        create(:traceability_link, source_requirement: req_a, target_requirement: req_b, link_type: :derives_from, created_by: user)
        different_source = build(:traceability_link, source_requirement: req_c, target_requirement: req_b, link_type: :derives_from, created_by: user)
        expect(different_source).to be_valid
      end
    end

    describe "confidence" do
      it "allows nil confidence" do
        link = build(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user, confidence: nil)
        expect(link).to be_valid
      end

      it "allows confidence between 0 and 1" do
        link = build(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user, confidence: 0.75)
        expect(link).to be_valid
      end

      it "rejects confidence below 0" do
        link = build(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user, confidence: -0.1)
        expect(link).not_to be_valid
      end

      it "rejects confidence above 1" do
        link = build(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user, confidence: 1.1)
        expect(link).not_to be_valid
      end

      it "allows confidence of exactly 0" do
        link = build(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user, confidence: 0.0)
        expect(link).to be_valid
      end

      it "allows confidence of exactly 1" do
        link = build(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user, confidence: 1.0)
        expect(link).to be_valid
      end
    end
  end

  describe "enums" do
    it "defines link_type enum with all expected values" do
      expect(described_class.link_types).to eq({
        "derives_from" => 0,
        "satisfies" => 1,
        "verifies" => 2,
        "conflicts_with" => 3,
        "refines" => 4,
        "implements" => 5,
        "parent_child" => 6
      })
    end

    it "defaults link_type to derives_from" do
      link = described_class.new
      expect(link.link_type).to eq("derives_from")
    end
  end

  describe "defaults" do
    it "defaults ai_suggested to false" do
      link = described_class.new
      expect(link.ai_suggested).to be false
    end
  end

  describe "#reverse_link_type" do
    it "returns satisfies for derives_from" do
      link = build(:traceability_link, link_type: :derives_from)
      expect(link.reverse_link_type).to eq("satisfies")
    end

    it "returns derives_from for satisfies" do
      link = build(:traceability_link, link_type: :satisfies)
      expect(link.reverse_link_type).to eq("derives_from")
    end

    it "returns derives_from for verifies" do
      link = build(:traceability_link, link_type: :verifies)
      expect(link.reverse_link_type).to eq("derives_from")
    end

    it "returns conflicts_with for conflicts_with (symmetric)" do
      link = build(:traceability_link, link_type: :conflicts_with)
      expect(link.reverse_link_type).to eq("conflicts_with")
    end

    it "returns parent_child for parent_child (symmetric)" do
      link = build(:traceability_link, link_type: :parent_child)
      expect(link.reverse_link_type).to eq("parent_child")
    end
  end

  describe ".links_for" do
    it "returns links where requirement is the source" do
      link = create(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user)
      expect(described_class.links_for(req_a)).to include(link)
    end

    it "returns links where requirement is the target" do
      link = create(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user)
      expect(described_class.links_for(req_b)).to include(link)
    end

    it "does not return unrelated links" do
      req_c = create(:requirement, project: project, section: section, created_by: user)
      req_d = create(:requirement, project: project, section: section, created_by: user)
      _unrelated = create(:traceability_link, source_requirement: req_c, target_requirement: req_d, created_by: user)
      link = create(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user)
      expect(described_class.links_for(req_a)).to eq([link])
    end
  end

  describe "#other_requirement" do
    it "returns target when called from source" do
      link = create(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user)
      expect(link.other_requirement(from: req_a)).to eq(req_b)
    end

    it "returns source when called from target" do
      link = create(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user)
      expect(link.other_requirement(from: req_b)).to eq(req_a)
    end
  end

  describe "paper_trail" do
    it "tracks creation" do
      link = create(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user)
      expect(link.versions.count).to eq(1)
    end

    it "tracks updates" do
      link = create(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user, link_type: :derives_from)
      link.update!(link_type: :satisfies)
      expect(link.versions.count).to eq(2)
    end

    it "can revert to previous version" do
      link = create(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user, link_type: :derives_from)
      link.update!(link_type: :satisfies)
      previous = link.versions.last.reify
      expect(previous.link_type).to eq("derives_from")
    end
  end

  describe "ai_suggested trait" do
    it "creates an AI-suggested link with confidence" do
      link = build(:traceability_link, :ai_suggested, source_requirement: req_a, target_requirement: req_b, created_by: user)
      expect(link.ai_suggested).to be true
      expect(link.confidence).to eq(0.85)
      expect(link).to be_valid
    end
  end

  describe "requirement associations" do
    it "appears in source requirement's outgoing_links" do
      link = create(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user)
      expect(req_a.outgoing_links).to include(link)
    end

    it "appears in target requirement's incoming_links" do
      link = create(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user)
      expect(req_b.incoming_links).to include(link)
    end

    it "is destroyed when source requirement is destroyed" do
      link = create(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user)
      req_a.destroy
      expect(TraceabilityLink.exists?(link.id)).to be false
    end

    it "is destroyed when target requirement is destroyed" do
      link = create(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user)
      req_b.destroy
      expect(TraceabilityLink.exists?(link.id)).to be false
    end
  end
end
