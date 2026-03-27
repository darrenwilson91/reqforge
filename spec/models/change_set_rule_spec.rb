require "rails_helper"

RSpec.describe ChangeSetRule, type: :model do
  describe "factory" do
    it "has a valid factory" do
      expect(build(:change_set_rule)).to be_valid
    end

    it "has a valid :strict trait" do
      rule = build(:change_set_rule, :strict)
      expect(rule).to be_valid
      expect(rule.min_approvals).to eq(2)
      expect(rule.require_all_conversations_resolved).to be true
      expect(rule.auto_merge_on_approval).to be false
    end

    it "has a valid :relaxed trait" do
      rule = build(:change_set_rule, :relaxed)
      expect(rule).to be_valid
      expect(rule.min_approvals).to eq(1)
      expect(rule.require_all_conversations_resolved).to be false
      expect(rule.auto_merge_on_approval).to be true
    end

    it "has a valid :auto_merge trait" do
      rule = build(:change_set_rule, :auto_merge)
      expect(rule).to be_valid
      expect(rule.auto_merge_on_approval).to be true
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end

  describe "validations" do
    subject { create(:change_set_rule) }

    it { is_expected.to validate_uniqueness_of(:project_id) }
    it { is_expected.to validate_presence_of(:min_approvals) }

    it {
      is_expected.to validate_numericality_of(:min_approvals)
        .only_integer
        .is_greater_than_or_equal_to(1)
        .is_less_than_or_equal_to(10)
    }

    it "rejects min_approvals of 0" do
      rule = build(:change_set_rule, min_approvals: 0)
      expect(rule).not_to be_valid
      expect(rule.errors[:min_approvals]).to be_present
    end

    it "rejects min_approvals of 11" do
      rule = build(:change_set_rule, min_approvals: 11)
      expect(rule).not_to be_valid
      expect(rule.errors[:min_approvals]).to be_present
    end

    it "rejects non-integer min_approvals" do
      rule = build(:change_set_rule, min_approvals: 1.5)
      expect(rule).not_to be_valid
      expect(rule.errors[:min_approvals]).to be_present
    end

    it "enforces one rule per project" do
      project = create(:project)
      create(:change_set_rule, project: project)
      duplicate = build(:change_set_rule, project: project)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:project_id]).to be_present
    end

    it "allows rules on different projects" do
      create(:change_set_rule)
      rule = build(:change_set_rule)
      expect(rule).to be_valid
    end
  end

  describe "defaults" do
    it "defaults min_approvals to 1" do
      rule = described_class.new
      expect(rule.min_approvals).to eq(1)
    end

    it "defaults require_all_conversations_resolved to true" do
      rule = described_class.new
      expect(rule.require_all_conversations_resolved).to be true
    end

    it "defaults auto_merge_on_approval to false" do
      rule = described_class.new
      expect(rule.auto_merge_on_approval).to be false
    end
  end

  describe "project association" do
    it "is accessible from the project" do
      project = create(:project)
      rule = create(:change_set_rule, project: project)
      expect(project.reload.change_set_rule).to eq(rule)
    end

    it "is destroyed when the project is destroyed" do
      project = create(:project)
      create(:change_set_rule, project: project)
      expect { project.destroy }.to change(described_class, :count).by(-1)
    end
  end

  describe "#merge_eligible?" do
    let(:project) { create(:project) }
    let(:rule) { create(:change_set_rule, project: project, min_approvals: 1) }
    let(:change_set) { create(:change_set, project: project) }

    context "when ChangeSetApproval model exists" do
      # ChangeSetApproval is not yet generated — these will be tested once it is
      it "returns false when there are no approvals" do
        pending "ChangeSetApproval model not yet generated"
        expect(rule.merge_eligible?(change_set)).to be false
      end
    end

    context "with min_approvals requirement" do
      let(:rule) { create(:change_set_rule, project: project, min_approvals: 2) }

      it "returns false when approval count is below minimum" do
        pending "ChangeSetApproval model not yet generated"
        expect(rule.merge_eligible?(change_set)).to be false
      end
    end

    context "with require_all_conversations_resolved" do
      let(:rule) do
        create(:change_set_rule,
               project: project,
               min_approvals: 1,
               require_all_conversations_resolved: true)
      end

      it "is configurable" do
        expect(rule.require_all_conversations_resolved?).to be true
      end
    end

    context "with auto_merge_on_approval" do
      let(:rule) do
        create(:change_set_rule,
               project: project,
               auto_merge_on_approval: true)
      end

      it "is configurable" do
        expect(rule.auto_merge_on_approval?).to be true
      end
    end
  end

  describe "boolean accessors" do
    it "responds to require_all_conversations_resolved?" do
      rule = build(:change_set_rule, require_all_conversations_resolved: true)
      expect(rule.require_all_conversations_resolved?).to be true

      rule.require_all_conversations_resolved = false
      expect(rule.require_all_conversations_resolved?).to be false
    end

    it "responds to auto_merge_on_approval?" do
      rule = build(:change_set_rule, auto_merge_on_approval: false)
      expect(rule.auto_merge_on_approval?).to be false

      rule.auto_merge_on_approval = true
      expect(rule.auto_merge_on_approval?).to be true
    end
  end
end
