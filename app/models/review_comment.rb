class ReviewComment < ApplicationRecord
  belongs_to :review_item
  belongs_to :user
  belongs_to :parent_comment, class_name: "ReviewComment", optional: true
  belongs_to :resolved_by, class_name: "User", optional: true

  has_many :replies, class_name: "ReviewComment", foreign_key: :parent_comment_id, dependent: :destroy

  has_paper_trail

  validates :body, presence: true
  validate :parent_must_belong_to_same_review_item

  scope :top_level, -> { where(parent_comment_id: nil) }
  scope :resolved, -> { where(resolved: true) }
  scope :unresolved, -> { where(resolved: false) }

  def resolve!(user)
    update!(resolved: true, resolved_by: user, resolved_at: Time.current)
  end

  def unresolve!
    update!(resolved: false, resolved_by: nil, resolved_at: nil)
  end

  def thread_depth
    depth = 0
    comment = self
    while comment.parent_comment_id.present?
      depth += 1
      comment = comment.parent_comment
    end
    depth
  end

  def top_level?
    parent_comment_id.nil?
  end

  private

  def parent_must_belong_to_same_review_item
    return if parent_comment.nil?

    if parent_comment.review_item_id != review_item_id
      errors.add(:parent_comment, "must belong to the same review item")
    end
  end
end
