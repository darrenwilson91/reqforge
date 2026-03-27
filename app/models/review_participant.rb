class ReviewParticipant < ApplicationRecord
  belongs_to :review
  belongs_to :user

  has_paper_trail

  enum :role, { author: 0, reviewer: 1, approver: 2, observer: 3 }

  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :review_id, message: "is already a participant in this review" }

  scope :reviewers, -> { where(role: :reviewer) }
  scope :approvers, -> { where(role: :approver) }
  scope :active_reviewers, -> { where(role: [:reviewer, :approver]) }

  def can_decide?
    reviewer? || approver?
  end

  def can_comment?
    !observer?
  end
end
