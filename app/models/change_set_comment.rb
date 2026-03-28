class ChangeSetComment < ApplicationRecord
  belongs_to :change_set
  belongs_to :change_set_change, optional: true
  belongs_to :user
  belongs_to :parent_comment, class_name: "ChangeSetComment", optional: true
  belongs_to :resolved_by, class_name: "User", optional: true

  has_many :replies, class_name: "ChangeSetComment", foreign_key: :parent_comment_id, dependent: :destroy

  has_paper_trail

  validates :body, presence: true
  validate :parent_must_be_in_same_change_set

  scope :top_level, -> { where(parent_comment_id: nil) }
  scope :conversation, -> { where(change_set_change_id: nil) }
  scope :inline, -> { where.not(change_set_change_id: nil) }
  scope :resolved, -> { where(resolved: true) }
  scope :unresolved, -> { where(resolved: false) }

  def resolve!(user)
    update!(resolved: true, resolved_by: user, resolved_at: Time.current)
  end

  def unresolve!
    update!(resolved: false, resolved_by: nil, resolved_at: nil)
  end

  def top_level?
    parent_comment_id.nil?
  end

  def inline?
    change_set_change_id.present?
  end

  def conversation?
    change_set_change_id.nil?
  end

  def thread_depth
    depth = 0
    current = self
    while current.parent_comment_id.present?
      depth += 1
      current = current.parent_comment
    end
    depth
  end

  private

  def parent_must_be_in_same_change_set
    return unless parent_comment.present?

    if parent_comment.change_set_id != change_set_id
      errors.add(:parent_comment, "must belong to the same change set")
    end
  end
end
