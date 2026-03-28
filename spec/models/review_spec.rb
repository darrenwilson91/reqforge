require 'rails_helper'

RSpec.describe Review, type: :model do
  describe "factory" do
    it "has a valid factory" do
      review = build(:review)
      expect(review).to be_valid
    end
  end

  describe "associations" do
    it { should belong_to(:project) }
    it { should belong_to(:created_by).class_name("User") }
    it { should have_many(:review_items).dependent(:destroy) }
    it { should have_many(:review_participants).dependent(:destroy) }
    it { should have_many(:participants).through(:review_participants).source(:user) }
  end

  describe "validations" do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:status) }

    it "rejects blank title" do
      review = build(:review, title: "")
      expect(review).not_to be_valid
      expect(review.errors[:title]).to include("can't be blank")
    end
  end

  describe "enum" do
    it { should define_enum_for(:status).with_values(draft: 0, open: 1, in_progress: 2, completed: 3, cancelled: 4) }
  end

  describe "defaults" do
    it "defaults status to draft" do
      review = Review.new
      expect(review.status).to eq("draft")
    end

    it "defaults baseline_snapshot to empty hash" do
      review = Review.new
      expect(review.baseline_snapshot).to eq({})
    end
  end

  describe "paper_trail" do
    it "tracks creation" do
      review = create(:review)
      expect(review.versions.count).to eq(1)
      expect(review.versions.last.event).to eq("create")
    end

    it "tracks updates" do
      review = create(:review)
      review.update!(title: "Updated Title")
      expect(review.versions.count).to eq(2)
      expect(review.versions.last.event).to eq("update")
    end
  end

  describe "#available_transitions" do
    it "returns [open, cancelled] for draft" do
      review = build(:review, status: :draft)
      expect(review.available_transitions).to eq(%w[open cancelled])
    end

    it "returns [in_progress, cancelled] for open" do
      review = build(:review, status: :open)
      expect(review.available_transitions).to eq(%w[in_progress cancelled])
    end

    it "returns [completed, cancelled] for in_progress" do
      review = build(:review, status: :in_progress)
      expect(review.available_transitions).to eq(%w[completed cancelled])
    end

    it "returns [] for completed" do
      review = build(:review, status: :completed)
      expect(review.available_transitions).to eq([])
    end

    it "returns [draft] for cancelled" do
      review = build(:review, status: :cancelled)
      expect(review.available_transitions).to eq(%w[draft])
    end
  end

  describe "#transition_to" do
    it "transitions draft to open" do
      review = create(:review, status: :draft)
      expect(review.transition_to(:open)).to be true
      expect(review.reload.status).to eq("open")
    end

    it "transitions open to in_progress" do
      review = create(:review, status: :open)
      expect(review.transition_to(:in_progress)).to be true
      expect(review.reload.status).to eq("in_progress")
    end

    it "transitions in_progress to completed" do
      review = create(:review, status: :in_progress)
      expect(review.transition_to(:completed)).to be true
      expect(review.reload.status).to eq("completed")
    end

    it "transitions any to cancelled" do
      review = create(:review, status: :open)
      expect(review.transition_to(:cancelled)).to be true
      expect(review.reload.status).to eq("cancelled")
    end

    it "transitions cancelled back to draft" do
      review = create(:review, status: :cancelled)
      expect(review.transition_to(:draft)).to be true
      expect(review.reload.status).to eq("draft")
    end

    it "rejects invalid transition (draft to completed)" do
      review = create(:review, status: :draft)
      expect(review.transition_to(:completed)).to be false
      expect(review.errors[:status]).to include("cannot transition from draft to completed")
      expect(review.reload.status).to eq("draft")
    end

    it "rejects transition from completed" do
      review = create(:review, status: :completed)
      expect(review.transition_to(:draft)).to be false
      expect(review.errors[:status]).to include("cannot transition from completed to draft")
    end

    it "tracks transition via paper_trail" do
      review = create(:review, status: :draft)
      review.transition_to(:open)
      expect(review.versions.last.event).to eq("update")
    end

    it "accepts string status" do
      review = create(:review, status: :draft)
      expect(review.transition_to("open")).to be true
      expect(review.reload.status).to eq("open")
    end
  end

  describe "#snapshot_requirements!" do
    let(:organization) { create(:organization) }
    let(:project) { create(:project, organization: organization) }
    let(:mod) { create(:requirement_module, project: project) }
    let(:section) { create(:section, requirement_module: mod) }
    let(:user) { create(:user) }
    let!(:req1) { create(:requirement, project: project, section: section, created_by: user, title: "First Req", body: "Body 1") }
    let!(:req2) { create(:requirement, project: project, section: section, created_by: user, title: "Second Req", body: "Body 2") }
    let(:review) { create(:review, project: project, created_by: user) }

    it "snapshots all project requirements" do
      review.snapshot_requirements!
      expect(review.baseline_snapshot.length).to eq(2)
    end

    it "captures requirement attributes in snapshot" do
      review.snapshot_requirements!
      snapshot = review.baseline_snapshot.find { |s| s["id"] == req1.id }
      expect(snapshot["uid"]).to eq(req1.uid)
      expect(snapshot["title"]).to eq("First Req")
      expect(snapshot["body"]).to eq("Body 1")
      expect(snapshot["requirement_type"]).to eq(req1.requirement_type)
      expect(snapshot["status"]).to eq(req1.status)
      expect(snapshot["module_name"]).to eq(mod.name)
      expect(snapshot["section_name"]).to eq(section.name)
    end

    it "persists snapshot to database" do
      review.snapshot_requirements!
      review.reload
      expect(review.baseline_snapshot).to be_an(Array)
      expect(review.baseline_snapshot.length).to eq(2)
    end

    it "handles empty project" do
      empty_project = create(:project, organization: organization)
      empty_review = create(:review, project: empty_project, created_by: user)
      empty_review.snapshot_requirements!
      expect(empty_review.baseline_snapshot).to eq([])
    end
  end

  describe "#progress" do
    let(:organization) { create(:organization) }
    let(:project) { create(:project, organization: organization) }
    let(:user) { create(:user) }
    let(:review) { create(:review, project: project, created_by: user) }

    it "returns zero progress with no items" do
      expect(review.progress).to eq({ total: 0, decided: 0, percentage: 0 })
    end

    it "returns correct progress with mixed items" do
      mod = create(:requirement_module, project: project)
      section = create(:section, requirement_module: mod)
      req1 = create(:requirement, project: project, section: section, created_by: user)
      req2 = create(:requirement, project: project, section: section, created_by: user)
      req3 = create(:requirement, project: project, section: section, created_by: user)

      create(:review_item, review: review, requirement: req1, status: :approved)
      create(:review_item, review: review, requirement: req2, status: :rejected)
      create(:review_item, review: review, requirement: req3, status: :pending)

      progress = review.progress
      expect(progress[:total]).to eq(3)
      expect(progress[:decided]).to eq(2)
      expect(progress[:percentage]).to eq(67)
    end

    it "returns 100% when all items decided" do
      mod = create(:requirement_module, project: project)
      section = create(:section, requirement_module: mod)
      req1 = create(:requirement, project: project, section: section, created_by: user)
      req2 = create(:requirement, project: project, section: section, created_by: user)

      create(:review_item, review: review, requirement: req1, status: :approved)
      create(:review_item, review: review, requirement: req2, status: :approved)

      expect(review.progress[:percentage]).to eq(100)
    end
  end

  describe "#all_items_decided?" do
    let(:organization) { create(:organization) }
    let(:project) { create(:project, organization: organization) }
    let(:user) { create(:user) }
    let(:review) { create(:review, project: project, created_by: user) }
    let(:mod) { create(:requirement_module, project: project) }
    let(:section) { create(:section, requirement_module: mod) }

    it "returns false with no items" do
      expect(review.all_items_decided?).to be false
    end

    it "returns false when some items are pending" do
      req1 = create(:requirement, project: project, section: section, created_by: user)
      req2 = create(:requirement, project: project, section: section, created_by: user)
      create(:review_item, review: review, requirement: req1, status: :approved)
      create(:review_item, review: review, requirement: req2, status: :pending)
      expect(review.all_items_decided?).to be false
    end

    it "returns true when all items are decided" do
      req1 = create(:requirement, project: project, section: section, created_by: user)
      req2 = create(:requirement, project: project, section: section, created_by: user)
      create(:review_item, review: review, requirement: req1, status: :approved)
      create(:review_item, review: review, requirement: req2, status: :rejected)
      expect(review.all_items_decided?).to be true
    end

    it "returns true when all items need changes" do
      req = create(:requirement, project: project, section: section, created_by: user)
      create(:review_item, review: review, requirement: req, status: :needs_changes)
      expect(review.all_items_decided?).to be true
    end
  end

  describe "#auto_complete_if_all_decided!" do
    let(:organization) { create(:organization) }
    let(:project) { create(:project, organization: organization) }
    let(:user) { create(:user) }
    let(:review) { create(:review, :in_progress, project: project, created_by: user) }
    let(:mod) { create(:requirement_module, project: project) }
    let(:section) { create(:section, requirement_module: mod) }

    it "transitions to completed when all items decided and review is in_progress" do
      req = create(:requirement, project: project, section: section, created_by: user)
      create(:review_item, review: review, requirement: req, status: :approved)
      expect(review.auto_complete_if_all_decided!).to be true
      expect(review.reload.status).to eq("completed")
    end

    it "returns false when not all items decided" do
      req1 = create(:requirement, project: project, section: section, created_by: user)
      req2 = create(:requirement, project: project, section: section, created_by: user)
      create(:review_item, review: review, requirement: req1, status: :approved)
      create(:review_item, review: review, requirement: req2, status: :pending)
      expect(review.auto_complete_if_all_decided!).to be false
      expect(review.reload.status).to eq("in_progress")
    end

    it "returns false when review is not in_progress" do
      draft_review = create(:review, :draft, project: project, created_by: user)
      req = create(:requirement, project: project, section: section, created_by: user)
      create(:review_item, review: draft_review, requirement: req, status: :approved)
      expect(draft_review.auto_complete_if_all_decided!).to be false
      expect(draft_review.reload.status).to eq("draft")
    end

    it "returns false when no items exist" do
      expect(review.auto_complete_if_all_decided!).to be false
    end

    it "tracks transition via paper_trail" do
      req = create(:requirement, project: project, section: section, created_by: user)
      create(:review_item, review: review, requirement: req, status: :approved)
      review.auto_complete_if_all_decided!
      expect(review.versions.last.event).to eq("update")
    end
  end

  describe "#overall_outcome" do
    let(:organization) { create(:organization) }
    let(:project) { create(:project, organization: organization) }
    let(:user) { create(:user) }
    let(:review) { create(:review, project: project, created_by: user) }
    let(:mod) { create(:requirement_module, project: project) }
    let(:section) { create(:section, requirement_module: mod) }

    it "returns nil with no items" do
      expect(review.overall_outcome).to be_nil
    end

    it "returns nil when some items are still pending" do
      req1 = create(:requirement, project: project, section: section, created_by: user)
      req2 = create(:requirement, project: project, section: section, created_by: user)
      create(:review_item, review: review, requirement: req1, status: :approved)
      create(:review_item, review: review, requirement: req2, status: :pending)
      expect(review.overall_outcome).to be_nil
    end

    it "returns :approved when all items are approved" do
      req1 = create(:requirement, project: project, section: section, created_by: user)
      req2 = create(:requirement, project: project, section: section, created_by: user)
      create(:review_item, review: review, requirement: req1, status: :approved)
      create(:review_item, review: review, requirement: req2, status: :approved)
      expect(review.overall_outcome).to eq(:approved)
    end

    it "returns :rejected when any item is rejected" do
      req1 = create(:requirement, project: project, section: section, created_by: user)
      req2 = create(:requirement, project: project, section: section, created_by: user)
      create(:review_item, review: review, requirement: req1, status: :approved)
      create(:review_item, review: review, requirement: req2, status: :rejected)
      expect(review.overall_outcome).to eq(:rejected)
    end

    it "returns :rejected when rejected takes precedence over needs_changes" do
      req1 = create(:requirement, project: project, section: section, created_by: user)
      req2 = create(:requirement, project: project, section: section, created_by: user)
      create(:review_item, review: review, requirement: req1, status: :needs_changes)
      create(:review_item, review: review, requirement: req2, status: :rejected)
      expect(review.overall_outcome).to eq(:rejected)
    end

    it "returns :needs_changes when some items need changes but none rejected" do
      req1 = create(:requirement, project: project, section: section, created_by: user)
      req2 = create(:requirement, project: project, section: section, created_by: user)
      create(:review_item, review: review, requirement: req1, status: :approved)
      create(:review_item, review: review, requirement: req2, status: :needs_changes)
      expect(review.overall_outcome).to eq(:needs_changes)
    end

    it "returns :approved for a single approved item" do
      req = create(:requirement, project: project, section: section, created_by: user)
      create(:review_item, review: review, requirement: req, status: :approved)
      expect(review.overall_outcome).to eq(:approved)
    end
  end

  describe "share token" do
    let(:organization) { create(:organization) }
    let(:project) { create(:project, organization: organization) }
    let(:user) { create(:user) }
    let(:review) { create(:review, project: project, created_by: user) }

    describe "validations" do
      it "allows nil share_token" do
        expect(review.share_token).to be_nil
        expect(review).to be_valid
      end

      it "validates uniqueness of share_token" do
        review.generate_share_token!
        other_review = create(:review, project: project, created_by: user)
        other_review.share_token = review.share_token
        expect(other_review).not_to be_valid
        expect(other_review.errors[:share_token]).to include("has already been taken")
      end
    end

    describe "#generate_share_token!" do
      it "generates a non-nil token" do
        review.generate_share_token!
        expect(review.share_token).to be_present
      end

      it "persists the token" do
        review.generate_share_token!
        expect(review.reload.share_token).to be_present
      end

      it "returns the token" do
        token = review.generate_share_token!
        expect(token).to eq(review.share_token)
      end

      it "generates unique tokens for different reviews" do
        other_review = create(:review, project: project, created_by: user)
        token1 = review.generate_share_token!
        token2 = other_review.generate_share_token!
        expect(token1).not_to eq(token2)
      end

      it "generates URL-safe tokens" do
        token = review.generate_share_token!
        expect(token).to match(/\A[A-Za-z0-9_-]+\z/)
      end
    end

    describe "#revoke_share_token!" do
      it "clears the share token" do
        review.generate_share_token!
        expect(review.share_token).to be_present
        review.revoke_share_token!
        expect(review.reload.share_token).to be_nil
      end
    end

    describe "#shared?" do
      it "returns false when no token" do
        expect(review.shared?).to be false
      end

      it "returns true when token present" do
        review.generate_share_token!
        expect(review.shared?).to be true
      end

      it "returns false after revoking" do
        review.generate_share_token!
        review.revoke_share_token!
        expect(review.shared?).to be false
      end
    end
  end
end
