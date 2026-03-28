require 'rails_helper'

RSpec.describe ReviewParticipant, type: :model do
  describe "factory" do
    it "has a valid factory" do
      participant = build(:review_participant)
      expect(participant).to be_valid
    end

    it "has valid trait factories" do
      %i[author reviewer approver observer].each do |trait|
        participant = build(:review_participant, trait)
        expect(participant).to be_valid
      end
    end
  end

  describe "associations" do
    it { should belong_to(:review) }
    it { should belong_to(:user) }
  end

  describe "validations" do
    it { should validate_presence_of(:role) }

    it "validates uniqueness of user within a review" do
      existing = create(:review_participant)
      duplicate = build(:review_participant, review: existing.review, user: existing.user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("is already a participant in this review")
    end

    it "allows the same user in different reviews" do
      user = create(:user)
      review1 = create(:review)
      review2 = create(:review)

      create(:review_participant, review: review1, user: user)
      participant2 = build(:review_participant, review: review2, user: user)
      expect(participant2).to be_valid
    end

    it "allows different users in the same review" do
      review = create(:review)
      user1 = create(:user)
      user2 = create(:user)

      create(:review_participant, review: review, user: user1)
      participant2 = build(:review_participant, review: review, user: user2)
      expect(participant2).to be_valid
    end
  end

  describe "enum" do
    it { should define_enum_for(:role).with_values(author: 0, reviewer: 1, approver: 2, observer: 3) }
  end

  describe "defaults" do
    it "defaults role to reviewer via factory" do
      participant = build(:review_participant)
      expect(participant.role).to eq("reviewer")
    end

    it "defaults role to author (0) at database level" do
      participant = ReviewParticipant.new
      expect(participant.role).to eq("author")
    end
  end

  describe "scopes" do
    let(:review) { create(:review) }
    let!(:author_participant) { create(:review_participant, :author, review: review) }
    let!(:reviewer_participant) { create(:review_participant, :reviewer, review: review) }
    let!(:approver_participant) { create(:review_participant, :approver, review: review) }
    let!(:observer_participant) { create(:review_participant, :observer, review: review) }

    describe ".reviewers" do
      it "returns only reviewer-role participants" do
        expect(ReviewParticipant.reviewers).to contain_exactly(reviewer_participant)
      end
    end

    describe ".approvers" do
      it "returns only approver-role participants" do
        expect(ReviewParticipant.approvers).to contain_exactly(approver_participant)
      end
    end

    describe ".active_reviewers" do
      it "returns reviewers and approvers" do
        expect(ReviewParticipant.active_reviewers).to contain_exactly(reviewer_participant, approver_participant)
      end
    end
  end

  describe "#can_decide?" do
    it "returns true for reviewer" do
      expect(build(:review_participant, :reviewer).can_decide?).to be true
    end

    it "returns true for approver" do
      expect(build(:review_participant, :approver).can_decide?).to be true
    end

    it "returns false for author" do
      expect(build(:review_participant, :author).can_decide?).to be false
    end

    it "returns false for observer" do
      expect(build(:review_participant, :observer).can_decide?).to be false
    end
  end

  describe "#can_comment?" do
    it "returns true for author" do
      expect(build(:review_participant, :author).can_comment?).to be true
    end

    it "returns true for reviewer" do
      expect(build(:review_participant, :reviewer).can_comment?).to be true
    end

    it "returns true for approver" do
      expect(build(:review_participant, :approver).can_comment?).to be true
    end

    it "returns false for observer" do
      expect(build(:review_participant, :observer).can_comment?).to be false
    end
  end

  describe "paper_trail" do
    it "tracks creation" do
      participant = create(:review_participant)
      expect(participant.versions.count).to eq(1)
      expect(participant.versions.last.event).to eq("create")
    end

    it "tracks role changes" do
      participant = create(:review_participant, :reviewer)
      participant.update!(role: :approver)
      expect(participant.versions.count).to eq(2)
      expect(participant.versions.last.event).to eq("update")
    end
  end

  describe "review participant roles integration" do
    let(:organization) { create(:organization) }
    let(:project) { create(:project, organization: organization) }
    let(:user) { create(:user) }
    let(:review) { create(:review, project: project, created_by: user) }

    it "allows multiple participants with different roles in one review" do
      user1 = create(:user)
      user2 = create(:user)
      user3 = create(:user)
      user4 = create(:user)

      author = create(:review_participant, :author, review: review, user: user1)
      reviewer = create(:review_participant, :reviewer, review: review, user: user2)
      approver = create(:review_participant, :approver, review: review, user: user3)
      observer = create(:review_participant, :observer, review: review, user: user4)

      expect(review.review_participants.count).to eq(4)
      expect(review.review_participants.reviewers).to contain_exactly(reviewer)
      expect(review.review_participants.approvers).to contain_exactly(approver)
      expect(review.review_participants.active_reviewers).to contain_exactly(reviewer, approver)
    end

    it "cascades destroy when review is deleted" do
      create(:review_participant, review: review)
      expect { review.destroy }.to change(ReviewParticipant, :count).by(-1)
    end
  end
end
