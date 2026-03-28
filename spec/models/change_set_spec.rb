require "rails_helper"

RSpec.describe ChangeSet, type: :model do
  describe "factory" do
    it "has a valid factory" do
      expect(build(:change_set)).to be_valid
    end

    it "has valid trait factories" do
      %i[open in_review approved merged closed with_baseline].each do |trait|
        expect(build(:change_set, trait)).to be_valid
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:created_by).class_name("User") }
    it { is_expected.to belong_to(:source_baseline).class_name("Review").optional }
    it { is_expected.to belong_to(:merged_by).class_name("User").optional }

    it { is_expected.to have_many(:change_set_changes).dependent(:destroy) }

    it { is_expected.to have_many(:change_set_approvals).dependent(:destroy) }
    it { is_expected.to have_many(:approvers).through(:change_set_approvals).source(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe "enum" do
    it { is_expected.to define_enum_for(:status).with_values(draft: 0, open: 1, in_review: 2, approved: 3, merged: 4, closed: 5) }
  end

  describe "defaults" do
    it "defaults to draft status" do
      change_set = ChangeSet.new
      expect(change_set.status).to eq("draft")
    end
  end

  describe "paper_trail" do
    it "tracks creation" do
      change_set = create(:change_set)
      expect(change_set.versions.count).to eq(1)
      expect(change_set.versions.last.event).to eq("create")
    end

    it "tracks updates" do
      change_set = create(:change_set)
      change_set.update!(title: "Updated Title")
      expect(change_set.versions.count).to eq(2)
      expect(change_set.versions.last.event).to eq("update")
    end
  end

  describe "#available_transitions" do
    it "returns valid transitions from draft" do
      change_set = build(:change_set, :draft)
      expect(change_set.available_transitions).to contain_exactly("open", "closed")
    end

    it "returns valid transitions from open" do
      change_set = build(:change_set, :open)
      expect(change_set.available_transitions).to contain_exactly("in_review", "closed")
    end

    it "returns valid transitions from in_review" do
      change_set = build(:change_set, :in_review)
      expect(change_set.available_transitions).to contain_exactly("approved", "closed")
    end

    it "returns valid transitions from approved" do
      change_set = build(:change_set, :approved)
      expect(change_set.available_transitions).to contain_exactly("merged", "closed")
    end

    it "returns no transitions from merged" do
      change_set = build(:change_set, :merged)
      expect(change_set.available_transitions).to be_empty
    end

    it "returns valid transitions from closed" do
      change_set = build(:change_set, :closed)
      expect(change_set.available_transitions).to contain_exactly("draft")
    end
  end

  describe "#transition_to" do
    it "transitions draft to open" do
      change_set = create(:change_set, :draft)
      expect(change_set.transition_to(:open)).to be true
      expect(change_set.reload).to be_open
    end

    it "transitions open to in_review" do
      change_set = create(:change_set, :open)
      expect(change_set.transition_to(:in_review)).to be true
      expect(change_set.reload).to be_in_review
    end

    it "transitions in_review to approved" do
      change_set = create(:change_set, :in_review)
      expect(change_set.transition_to(:approved)).to be true
      expect(change_set.reload).to be_approved
    end

    it "rejects invalid transition from draft to approved" do
      change_set = create(:change_set, :draft)
      expect(change_set.transition_to(:approved)).to be false
      expect(change_set.errors[:status]).to include("cannot transition from draft to approved")
    end

    it "rejects invalid transition from draft to merged" do
      change_set = create(:change_set, :draft)
      expect(change_set.transition_to(:merged)).to be false
    end

    it "allows any status to transition to closed" do
      %i[draft open in_review approved].each do |status|
        change_set = create(:change_set, status)
        expect(change_set.transition_to(:closed)).to be true
        expect(change_set.reload).to be_closed
      end
    end

    it "allows closed to transition back to draft" do
      change_set = create(:change_set, :closed)
      expect(change_set.transition_to(:draft)).to be true
      expect(change_set.reload).to be_draft
    end

    it "does not allow transitions from merged" do
      change_set = create(:change_set, :merged)
      expect(change_set.transition_to(:draft)).to be false
      expect(change_set.transition_to(:closed)).to be false
    end

    it "tracks transitions with paper_trail" do
      change_set = create(:change_set, :draft)
      change_set.transition_to(:open)
      expect(change_set.versions.last.event).to eq("update")
    end

    it "accepts string status" do
      change_set = create(:change_set, :draft)
      expect(change_set.transition_to("open")).to be true
      expect(change_set.reload).to be_open
    end
  end

  describe "#progress" do
    it "returns zero progress with no approvals" do
      change_set = create(:change_set)
      expect(change_set.progress).to eq({ total: 0, decided: 0, percentage: 0 })
    end

    it "calculates progress with mixed approvals" do
      change_set = create(:change_set)
      create(:change_set_approval, change_set: change_set)
      create(:change_set_approval, :approved, change_set: change_set)
      create(:change_set_approval, :changes_requested, change_set: change_set)
      result = change_set.progress
      expect(result[:total]).to eq(3)
      expect(result[:decided]).to eq(2)
      expect(result[:percentage]).to eq(67)
    end

    it "returns 100% when all decided" do
      change_set = create(:change_set)
      create(:change_set_approval, :approved, change_set: change_set)
      create(:change_set_approval, :approved, change_set: change_set)
      result = change_set.progress
      expect(result[:percentage]).to eq(100)
    end
  end

  describe "#all_approved?" do
    it "returns false with no approvals" do
      change_set = create(:change_set)
      expect(change_set.all_approved?).to be false
    end

    it "returns true when all approved" do
      change_set = create(:change_set)
      create(:change_set_approval, :approved, change_set: change_set)
      create(:change_set_approval, :approved, change_set: change_set)
      expect(change_set.all_approved?).to be true
    end

    it "returns false with mixed statuses" do
      change_set = create(:change_set)
      create(:change_set_approval, :approved, change_set: change_set)
      create(:change_set_approval, :changes_requested, change_set: change_set)
      expect(change_set.all_approved?).to be false
    end
  end

  describe "#any_changes_requested?" do
    it "returns false with no approvals" do
      change_set = create(:change_set)
      expect(change_set.any_changes_requested?).to be false
    end

    it "returns true with changes_requested" do
      change_set = create(:change_set)
      create(:change_set_approval, :changes_requested, change_set: change_set)
      expect(change_set.any_changes_requested?).to be true
    end
  end

  describe "#changes_count" do
    it "returns zeros for empty change set" do
      change_set = create(:change_set)
      expect(change_set.changes_count).to eq({ created: 0, modified: 0, deleted: 0 })
    end

    it "returns counts by change type" do
      change_set = create(:change_set)
      create(:change_set_change, :created, change_set: change_set)
      create(:change_set_change, :modified, change_set: change_set)
      create(:change_set_change, :modified, change_set: change_set)
      create(:change_set_change, :deleted, change_set: change_set)
      expect(change_set.changes_count).to eq({ created: 1, modified: 2, deleted: 1 })
    end
  end

  describe "#merge!" do
    it "returns false for non-approved change set" do
      project = create(:project)
      change_set = create(:change_set, :in_review, project: project)
      user = create(:user)
      expect(change_set.merge!(user: user)).to be false
    end

    it "merges an approved change set with changes applied" do
      project = create(:project)
      change_set = create(:change_set, :approved, project: project)
      requirement = create(:requirement, project: project, title: "Old Title")
      create(:change_set_change, :modified, change_set: change_set, requirement: requirement,
        after_snapshot: { "title" => "New Title", "body" => "Updated", "requirement_type" => "functional",
                         "status" => "draft", "priority" => "must_have", "asil_level" => "qm",
                         "custom_attributes" => {}, "uid" => requirement.uid })
      user = create(:user)

      result = change_set.merge!(user: user, message: "Approved by team")
      expect(result).to be true

      change_set.reload
      expect(change_set).to be_merged
      expect(change_set.merged_by).to eq(user)
      expect(change_set.merged_at).to be_present
      expect(change_set.merge_commit_message).to eq("Approved by team")

      requirement.reload
      expect(requirement.title).to eq("New Title")
    end

    it "merges without a message" do
      project = create(:project)
      change_set = create(:change_set, :approved, project: project)
      user = create(:user)

      result = change_set.merge!(user: user)
      expect(result).to be true

      change_set.reload
      expect(change_set).to be_merged
      expect(change_set.merge_commit_message).to be_nil
    end
  end

  describe "project association" do
    it "adds to project's change_sets" do
      project = create(:project)
      change_set = create(:change_set, project: project)
      expect(project.change_sets).to include(change_set)
    end
  end
end
