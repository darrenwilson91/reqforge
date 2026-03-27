class ChangeSetApproval < ApplicationRecord
  belongs_to :change_set
  belongs_to :user

  has_paper_trail

  enum :status, { pending: 0, approved: 1, changes_requested: 2, commented: 3 }

  validates :status, presence: true
  validates :user_id, uniqueness: { scope: :change_set_id, message: "already has an approval for this change set" }

  scope :decided, -> { where.not(status: :pending) }
  scope :approvals, -> { where(status: :approved) }
  scope :requests_for_changes, -> { where(status: :changes_requested) }

  def decided?
    !pending?
  end
end
