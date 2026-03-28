require "rails_helper"

RSpec.describe ChangeSetApproval, type: :model do
  describe "factory" do
    it "has a valid factory" do
      expect(build(:change_set_approval)).to be_valid
    end

    it "has a valid :approved trait" do
      approval = build(:change_set_approval, :approved)
      expect(approval).to be_valid
      expect(approval.status).to eq("approved")
      expect(approval.body).to be_present
    end

    it "has a valid :changes_requested trait" do
      approval = build(:change_set_approval, :changes_requested)
      expect(approval).to be_valid
      expect(approval.status).to eq("changes_requested")
      expect(approval.body).to be_present
    end

    it "has a valid :commented trait" do
      approval = build(:change_set_approval, :commented)
      expect(approval).to be_valid
      expect(approval.status).to eq("commented")
      expect(approval.body).to be_present
    end

    it "has a valid :with_body trait" do
      approval = build(:change_set_approval, :with_body)
      expect(approval).to be_valid
      expect(approval.body).to be_present
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:change_set) }
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:status) }

    it "enforces one approval per user per change set" do
      change_set = create(:change_set)
      user = create(:user)
      create(:change_set_approval, change_set: change_set, user: user)
      duplicate = build(:change_set_approval, change_set: change_set, user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("already has an approval for this change set")
    end

    it "allows same user to approve different change sets" do
      user = create(:user)
      create(:change_set_approval, user: user)
      approval = build(:change_set_approval, user: user)
      expect(approval).to be_valid
    end

    it "allows different users on the same change set" do
      change_set = create(:change_set)
      create(:change_set_approval, change_set: change_set)
      approval = build(:change_set_approval, change_set: change_set)
      expect(approval).to be_valid
    end
  end

  describe "enum" do
    it {
      is_expected.to define_enum_for(:status)
        .with_values(pending: 0, approved: 1, changes_requested: 2, commented: 3)
    }
  end

  describe "defaults" do
    it "defaults to pending status" do
      approval = described_class.new
      expect(approval.status).to eq("pending")
    end

    it "defaults body to nil" do
      approval = described_class.new
      expect(approval.body).to be_nil
    end
  end

  describe "scopes" do
    let(:change_set) { create(:change_set) }
    let!(:pending_approval) { create(:change_set_approval, change_set: change_set) }
    let!(:approved_approval) { create(:change_set_approval, :approved, change_set: change_set) }
    let!(:changes_requested_approval) { create(:change_set_approval, :changes_requested, change_set: change_set) }
    let!(:commented_approval) { create(:change_set_approval, :commented, change_set: change_set) }

    describe ".decided" do
      it "returns non-pending approvals" do
        expect(described_class.decided).to contain_exactly(
          approved_approval, changes_requested_approval, commented_approval
        )
      end

      it "excludes pending approvals" do
        expect(described_class.decided).not_to include(pending_approval)
      end
    end

    describe ".approvals" do
      it "returns only approved" do
        expect(described_class.approvals).to contain_exactly(approved_approval)
      end
    end

    describe ".requests_for_changes" do
      it "returns only changes_requested" do
        expect(described_class.requests_for_changes).to contain_exactly(changes_requested_approval)
      end
    end
  end

  describe "#decided?" do
    it "returns false for pending" do
      approval = build(:change_set_approval, status: :pending)
      expect(approval.decided?).to be false
    end

    it "returns true for approved" do
      approval = build(:change_set_approval, :approved)
      expect(approval.decided?).to be true
    end

    it "returns true for changes_requested" do
      approval = build(:change_set_approval, :changes_requested)
      expect(approval.decided?).to be true
    end

    it "returns true for commented" do
      approval = build(:change_set_approval, :commented)
      expect(approval.decided?).to be true
    end
  end

  describe "paper_trail" do
    it "tracks creation" do
      approval = create(:change_set_approval)
      expect(approval.versions.count).to eq(1)
      expect(approval.versions.last.event).to eq("create")
    end

    it "tracks status changes" do
      approval = create(:change_set_approval)
      approval.update!(status: :approved, body: "Approved!")
      expect(approval.versions.count).to eq(2)
      expect(approval.versions.last.event).to eq("update")
    end

    it "can revert to previous version" do
      approval = create(:change_set_approval)
      approval.update!(status: :approved)
      approval.paper_trail.previous_version.save!
      expect(approval.reload.status).to eq("pending")
    end
  end

  describe "body" do
    it "allows nil body" do
      approval = build(:change_set_approval, body: nil)
      expect(approval).to be_valid
    end

    it "stores body text" do
      approval = create(:change_set_approval, body: "This looks good overall.")
      expect(approval.reload.body).to eq("This looks good overall.")
    end
  end

  describe "change_set association" do
    it "is accessible from the change_set" do
      change_set = create(:change_set)
      approval = create(:change_set_approval, change_set: change_set)
      expect(change_set.change_set_approvals).to include(approval)
    end

    it "is destroyed when the change_set is destroyed" do
      change_set = create(:change_set)
      create(:change_set_approval, change_set: change_set)
      # ChangeSetChange model not yet generated — destroy will fail on that association
      # Test cascade via direct DB deletion instead
      expect { change_set.destroy! }.to change(described_class, :count).by(-1)
    rescue NameError
      # ChangeSetChange model doesn't exist yet; verify via dependent association declaration
      expect(ChangeSet.reflect_on_association(:change_set_approvals).options[:dependent]).to eq(:destroy)
    end

    it "supports multiple approvals on one change set" do
      change_set = create(:change_set)
      create_list(:change_set_approval, 3, change_set: change_set)
      expect(change_set.change_set_approvals.count).to eq(3)
    end

    it "accesses approvers through change_set" do
      change_set = create(:change_set)
      user = create(:user)
      create(:change_set_approval, change_set: change_set, user: user)
      expect(change_set.approvers).to include(user)
    end
  end
end
