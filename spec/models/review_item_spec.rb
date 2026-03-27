require 'rails_helper'

RSpec.describe ReviewItem, type: :model do
  let(:organization) { create(:organization) }
  let(:project) { create(:project, organization: organization) }
  let(:user) { create(:user) }
  let(:mod) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: mod) }
  let(:requirement) { create(:requirement, project: project, section: section, created_by: user) }
  let(:review) { create(:review, project: project, created_by: user) }

  describe "factory" do
    it "has a valid factory" do
      review_item = build(:review_item, review: review, requirement: requirement)
      expect(review_item).to be_valid
    end
  end

  describe "associations" do
    it { should belong_to(:review) }
    it { should belong_to(:requirement) }
    it { should have_many(:review_comments).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:status) }

    it "enforces uniqueness of requirement within a review" do
      create(:review_item, review: review, requirement: requirement)
      duplicate = build(:review_item, review: review, requirement: requirement)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:requirement_id]).to include("is already included in this review")
    end

    it "allows same requirement in different reviews" do
      review2 = create(:review, project: project, created_by: user, title: "Second Review")
      create(:review_item, review: review, requirement: requirement)
      item2 = build(:review_item, review: review2, requirement: requirement)
      expect(item2).to be_valid
    end
  end

  describe "enum" do
    it { should define_enum_for(:status).with_values(pending: 0, approved: 1, rejected: 2, needs_changes: 3) }
  end

  describe "defaults" do
    it "defaults status to pending" do
      item = ReviewItem.new
      expect(item.status).to eq("pending")
    end

    it "defaults snapshot to empty hash" do
      item = ReviewItem.new
      expect(item.snapshot).to eq({})
    end
  end

  describe "paper_trail" do
    it "tracks creation" do
      item = create(:review_item, review: review, requirement: requirement)
      expect(item.versions.count).to eq(1)
      expect(item.versions.last.event).to eq("create")
    end

    it "tracks status changes" do
      item = create(:review_item, review: review, requirement: requirement)
      item.update!(status: :approved)
      expect(item.versions.count).to eq(2)
      expect(item.versions.last.event).to eq("update")
    end
  end

  describe "#snapshot_requirement!" do
    it "captures requirement attributes in snapshot" do
      item = create(:review_item, review: review, requirement: requirement)
      item.snapshot_requirement!

      expect(item.snapshot["uid"]).to eq(requirement.uid)
      expect(item.snapshot["title"]).to eq(requirement.title)
      expect(item.snapshot["body"]).to eq(requirement.body)
      expect(item.snapshot["requirement_type"]).to eq(requirement.requirement_type)
      expect(item.snapshot["status"]).to eq(requirement.status)
      expect(item.snapshot["priority"]).to eq(requirement.priority)
      expect(item.snapshot["asil_level"]).to eq(requirement.asil_level)
      expect(item.snapshot["module_name"]).to eq(mod.name)
      expect(item.snapshot["section_name"]).to eq(section.name)
    end

    it "persists snapshot to database" do
      item = create(:review_item, review: review, requirement: requirement)
      item.snapshot_requirement!
      item.reload
      expect(item.snapshot).to be_a(Hash)
      expect(item.snapshot["uid"]).to eq(requirement.uid)
    end

    it "captures custom attributes" do
      requirement.update!(custom_attributes: { "weight" => "1.5kg", "material" => "steel" })
      item = create(:review_item, review: review, requirement: requirement)
      item.snapshot_requirement!
      expect(item.snapshot["custom_attributes"]).to eq({ "weight" => "1.5kg", "material" => "steel" })
    end
  end

  describe "#decided?" do
    it "returns false for pending items" do
      item = build(:review_item, status: :pending)
      expect(item.decided?).to be false
    end

    it "returns true for approved items" do
      item = build(:review_item, status: :approved)
      expect(item.decided?).to be true
    end

    it "returns true for rejected items" do
      item = build(:review_item, status: :rejected)
      expect(item.decided?).to be true
    end

    it "returns true for needs_changes items" do
      item = build(:review_item, status: :needs_changes)
      expect(item.decided?).to be true
    end
  end

  describe "#changed_since_snapshot?" do
    let(:item) { create(:review_item, review: review, requirement: requirement) }

    before { item.snapshot_requirement! }

    it "returns false when requirement unchanged" do
      expect(item.changed_since_snapshot?).to be false
    end

    it "returns false when snapshot is blank" do
      item.update_column(:snapshot, {})
      expect(item.changed_since_snapshot?).to be false
    end

    it "detects title change" do
      requirement.update!(title: "Changed Title")
      expect(item.changed_since_snapshot?).to be true
    end

    it "detects body change" do
      requirement.update!(body: "Changed body text")
      expect(item.changed_since_snapshot?).to be true
    end

    it "detects requirement_type change" do
      requirement.update!(requirement_type: :safety)
      expect(item.changed_since_snapshot?).to be true
    end

    it "detects status change" do
      requirement.update!(status: :in_review)
      expect(item.changed_since_snapshot?).to be true
    end

    it "detects priority change" do
      requirement.update!(priority: :could_have)
      expect(item.changed_since_snapshot?).to be true
    end

    it "detects asil_level change" do
      requirement.update!(asil_level: :asil_d)
      expect(item.changed_since_snapshot?).to be true
    end
  end

  describe "factory traits" do
    it "creates approved item" do
      item = build(:review_item, :approved)
      expect(item.status).to eq("approved")
    end

    it "creates rejected item" do
      item = build(:review_item, :rejected)
      expect(item.status).to eq("rejected")
    end

    it "creates needs_changes item" do
      item = build(:review_item, :needs_changes)
      expect(item.status).to eq("needs_changes")
    end

    it "creates item with snapshot" do
      item = create(:review_item, :with_snapshot, review: review, requirement: requirement)
      expect(item.snapshot).to be_present
      expect(item.snapshot["uid"]).to eq(requirement.uid)
    end
  end
end
