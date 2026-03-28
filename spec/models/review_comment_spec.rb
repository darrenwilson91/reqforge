require 'rails_helper'

RSpec.describe ReviewComment, type: :model do
  let(:organization) { create(:organization) }
  let(:project) { create(:project, organization: organization) }
  let(:user) { create(:user) }
  let(:mod) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: mod) }
  let(:requirement) { create(:requirement, project: project, section: section, created_by: user) }
  let(:review) { create(:review, project: project, created_by: user) }
  let(:review_item) { create(:review_item, review: review, requirement: requirement) }

  describe "factory" do
    it "has a valid factory" do
      comment = build(:review_comment, review_item: review_item, user: user)
      expect(comment).to be_valid
    end
  end

  describe "associations" do
    it { should belong_to(:review_item) }
    it { should belong_to(:user) }
    it { should belong_to(:parent_comment).class_name("ReviewComment").optional }
    it { should belong_to(:resolved_by).class_name("User").optional }
    it { should have_many(:replies).class_name("ReviewComment").dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:body) }

    it "rejects blank body" do
      comment = build(:review_comment, review_item: review_item, user: user, body: "")
      expect(comment).not_to be_valid
      expect(comment.errors[:body]).to include("can't be blank")
    end

    it "allows a reply to the same review item" do
      parent = create(:review_comment, review_item: review_item, user: user)
      reply = build(:review_comment, review_item: review_item, user: user, parent_comment: parent)
      expect(reply).to be_valid
    end

    it "rejects a reply to a different review item" do
      other_req = create(:requirement, project: project, section: section, created_by: user)
      other_item = create(:review_item, review: review, requirement: other_req)
      parent = create(:review_comment, review_item: other_item, user: user)

      reply = build(:review_comment, review_item: review_item, user: user, parent_comment: parent)
      expect(reply).not_to be_valid
      expect(reply.errors[:parent_comment]).to include("must belong to the same review item")
    end
  end

  describe "defaults" do
    it "defaults resolved to false" do
      comment = ReviewComment.new
      expect(comment.resolved).to be false
    end
  end

  describe "scopes" do
    let!(:top_level) { create(:review_comment, review_item: review_item, user: user) }
    let!(:reply) { create(:review_comment, review_item: review_item, user: user, parent_comment: top_level) }
    let!(:resolved_comment) { create(:review_comment, :resolved, review_item: review_item, user: user) }

    describe ".top_level" do
      it "returns only comments without a parent" do
        expect(ReviewComment.top_level).to include(top_level, resolved_comment)
        expect(ReviewComment.top_level).not_to include(reply)
      end
    end

    describe ".resolved" do
      it "returns only resolved comments" do
        expect(ReviewComment.resolved).to include(resolved_comment)
        expect(ReviewComment.resolved).not_to include(top_level, reply)
      end
    end

    describe ".unresolved" do
      it "returns only unresolved comments" do
        expect(ReviewComment.unresolved).to include(top_level, reply)
        expect(ReviewComment.unresolved).not_to include(resolved_comment)
      end
    end
  end

  describe "threading" do
    let!(:root) { create(:review_comment, review_item: review_item, user: user, body: "Root comment") }
    let!(:reply1) { create(:review_comment, review_item: review_item, user: user, parent_comment: root, body: "Reply 1") }
    let!(:reply2) { create(:review_comment, review_item: review_item, user: user, parent_comment: root, body: "Reply 2") }
    let!(:nested_reply) { create(:review_comment, review_item: review_item, user: user, parent_comment: reply1, body: "Nested reply") }

    it "returns replies for a parent comment" do
      expect(root.replies).to include(reply1, reply2)
      expect(root.replies).not_to include(nested_reply)
    end

    it "supports nested replies" do
      expect(reply1.replies).to include(nested_reply)
    end

    it "cascade destroys replies when parent is destroyed" do
      expect { root.destroy }.to change(ReviewComment, :count).by(-4)
    end
  end

  describe "#top_level?" do
    it "returns true for comments without a parent" do
      comment = build(:review_comment, parent_comment: nil)
      expect(comment.top_level?).to be true
    end

    it "returns false for replies" do
      parent = create(:review_comment, review_item: review_item, user: user)
      reply = build(:review_comment, review_item: review_item, user: user, parent_comment: parent)
      expect(reply.top_level?).to be false
    end
  end

  describe "#thread_depth" do
    it "returns 0 for top-level comments" do
      comment = create(:review_comment, review_item: review_item, user: user)
      expect(comment.thread_depth).to eq(0)
    end

    it "returns 1 for direct replies" do
      parent = create(:review_comment, review_item: review_item, user: user)
      reply = create(:review_comment, review_item: review_item, user: user, parent_comment: parent)
      expect(reply.thread_depth).to eq(1)
    end

    it "returns 2 for nested replies" do
      root = create(:review_comment, review_item: review_item, user: user)
      reply = create(:review_comment, review_item: review_item, user: user, parent_comment: root)
      nested = create(:review_comment, review_item: review_item, user: user, parent_comment: reply)
      expect(nested.thread_depth).to eq(2)
    end
  end

  describe "#resolve!" do
    it "marks the comment as resolved" do
      comment = create(:review_comment, review_item: review_item, user: user)
      resolver = create(:user)
      comment.resolve!(resolver)

      comment.reload
      expect(comment.resolved).to be true
      expect(comment.resolved_by).to eq(resolver)
      expect(comment.resolved_at).to be_present
    end
  end

  describe "#unresolve!" do
    it "clears the resolved state" do
      comment = create(:review_comment, :resolved, review_item: review_item, user: user)
      expect(comment.resolved).to be true

      comment.unresolve!
      comment.reload
      expect(comment.resolved).to be false
      expect(comment.resolved_by).to be_nil
      expect(comment.resolved_at).to be_nil
    end
  end

  describe "paper_trail" do
    it "tracks creation" do
      comment = create(:review_comment, review_item: review_item, user: user)
      expect(comment.versions.count).to eq(1)
      expect(comment.versions.last.event).to eq("create")
    end

    it "tracks updates" do
      comment = create(:review_comment, review_item: review_item, user: user)
      comment.update!(body: "Updated comment body")
      expect(comment.versions.count).to eq(2)
      expect(comment.versions.last.event).to eq("update")
    end

    it "tracks resolve action" do
      comment = create(:review_comment, review_item: review_item, user: user)
      resolver = create(:user)
      comment.resolve!(resolver)
      expect(comment.versions.count).to eq(2)
    end
  end

  describe "factory traits" do
    it "creates resolved comment" do
      comment = create(:review_comment, :resolved, review_item: review_item, user: user)
      expect(comment.resolved).to be true
      expect(comment.resolved_by).to be_present
      expect(comment.resolved_at).to be_present
    end

    it "creates reply comment" do
      comment = create(:review_comment, :reply, review_item: review_item, user: user)
      expect(comment.parent_comment).to be_present
      expect(comment.parent_comment.review_item).to eq(review_item)
    end
  end
end
