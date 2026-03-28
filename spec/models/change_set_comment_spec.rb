require "rails_helper"

RSpec.describe ChangeSetComment, type: :model do
  describe "factory" do
    it "has a valid default factory" do
      comment = build(:change_set_comment)
      expect(comment).to be_valid
    end

    it "has a valid inline factory" do
      change = create(:change_set_change)
      comment = build(:change_set_comment, :inline, change_set: change.change_set, change_set_change: change)
      expect(comment).to be_valid
    end

    it "has a valid resolved factory" do
      comment = build(:change_set_comment, :resolved)
      expect(comment).to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:change_set) }
    it { is_expected.to belong_to(:change_set_change).optional }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:parent_comment).class_name("ChangeSetComment").optional }
    it { is_expected.to belong_to(:resolved_by).class_name("User").optional }
    it { is_expected.to have_many(:replies).class_name("ChangeSetComment").dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:body) }

    it "validates parent_comment belongs to same change set" do
      cs1 = create(:change_set)
      cs2 = create(:change_set)
      parent = create(:change_set_comment, change_set: cs1)
      child = build(:change_set_comment, change_set: cs2, parent_comment: parent)
      expect(child).not_to be_valid
      expect(child.errors[:parent_comment]).to include("must belong to the same change set")
    end

    it "allows parent_comment in the same change set" do
      cs = create(:change_set)
      parent = create(:change_set_comment, change_set: cs)
      child = build(:change_set_comment, change_set: cs, parent_comment: parent)
      expect(child).to be_valid
    end
  end

  describe "scopes" do
    let(:change_set) { create(:change_set) }
    let(:change) { create(:change_set_change, change_set: change_set) }

    it ".top_level returns comments without parent" do
      top = create(:change_set_comment, change_set: change_set)
      reply = create(:change_set_comment, change_set: change_set, parent_comment: top)
      expect(described_class.top_level).to include(top)
      expect(described_class.top_level).not_to include(reply)
    end

    it ".conversation returns comments without a change" do
      conv = create(:change_set_comment, change_set: change_set, change_set_change: nil)
      inline = create(:change_set_comment, change_set: change_set, change_set_change: change)
      expect(described_class.conversation).to include(conv)
      expect(described_class.conversation).not_to include(inline)
    end

    it ".inline returns comments with a change" do
      conv = create(:change_set_comment, change_set: change_set, change_set_change: nil)
      inline = create(:change_set_comment, change_set: change_set, change_set_change: change)
      expect(described_class.inline).to include(inline)
      expect(described_class.inline).not_to include(conv)
    end

    it ".resolved returns only resolved comments" do
      resolved = create(:change_set_comment, :resolved, change_set: change_set)
      unresolved = create(:change_set_comment, change_set: change_set)
      expect(described_class.resolved).to include(resolved)
      expect(described_class.resolved).not_to include(unresolved)
    end

    it ".unresolved returns only unresolved comments" do
      resolved = create(:change_set_comment, :resolved, change_set: change_set)
      unresolved = create(:change_set_comment, change_set: change_set)
      expect(described_class.unresolved).to include(unresolved)
      expect(described_class.unresolved).not_to include(resolved)
    end
  end

  describe "#resolve!" do
    it "marks the comment as resolved" do
      comment = create(:change_set_comment)
      resolver = create(:user)
      comment.resolve!(resolver)
      expect(comment.resolved).to be true
      expect(comment.resolved_by).to eq(resolver)
      expect(comment.resolved_at).to be_present
    end
  end

  describe "#unresolve!" do
    it "clears resolved state" do
      comment = create(:change_set_comment, :resolved)
      comment.unresolve!
      expect(comment.resolved).to be false
      expect(comment.resolved_by).to be_nil
      expect(comment.resolved_at).to be_nil
    end
  end

  describe "#top_level?" do
    it "returns true when no parent" do
      comment = build(:change_set_comment, parent_comment: nil)
      expect(comment.top_level?).to be true
    end

    it "returns false when has parent" do
      cs = create(:change_set)
      parent = create(:change_set_comment, change_set: cs)
      child = build(:change_set_comment, change_set: cs, parent_comment: parent)
      expect(child.top_level?).to be false
    end
  end

  describe "#inline?" do
    it "returns true when has a change" do
      change = create(:change_set_change)
      comment = build(:change_set_comment, change_set: change.change_set, change_set_change: change)
      expect(comment.inline?).to be true
    end

    it "returns false when no change" do
      comment = build(:change_set_comment, change_set_change: nil)
      expect(comment.inline?).to be false
    end
  end

  describe "#conversation?" do
    it "returns true when no change" do
      comment = build(:change_set_comment, change_set_change: nil)
      expect(comment.conversation?).to be true
    end

    it "returns false when has a change" do
      change = create(:change_set_change)
      comment = build(:change_set_comment, change_set: change.change_set, change_set_change: change)
      expect(comment.conversation?).to be false
    end
  end

  describe "#thread_depth" do
    let(:change_set) { create(:change_set) }

    it "returns 0 for top-level" do
      comment = create(:change_set_comment, change_set: change_set)
      expect(comment.thread_depth).to eq(0)
    end

    it "returns 1 for direct reply" do
      parent = create(:change_set_comment, change_set: change_set)
      reply = create(:change_set_comment, change_set: change_set, parent_comment: parent)
      expect(reply.thread_depth).to eq(1)
    end

    it "returns 2 for nested reply" do
      p1 = create(:change_set_comment, change_set: change_set)
      p2 = create(:change_set_comment, change_set: change_set, parent_comment: p1)
      p3 = create(:change_set_comment, change_set: change_set, parent_comment: p2)
      expect(p3.thread_depth).to eq(2)
    end
  end

  describe "threading" do
    let(:change_set) { create(:change_set) }

    it "cascades destroy to replies" do
      parent = create(:change_set_comment, change_set: change_set)
      create(:change_set_comment, change_set: change_set, parent_comment: parent)
      expect { parent.destroy }.to change(described_class, :count).by(-2)
    end
  end

  describe "paper_trail" do
    it "tracks creation" do
      comment = create(:change_set_comment)
      expect(comment.versions.count).to eq(1)
      expect(comment.versions.last.event).to eq("create")
    end

    it "tracks updates" do
      comment = create(:change_set_comment)
      comment.update!(body: "Updated body")
      expect(comment.versions.count).to eq(2)
    end
  end

  describe "defaults" do
    it "defaults resolved to false" do
      comment = build(:change_set_comment)
      expect(comment.resolved).to be false
    end
  end
end
