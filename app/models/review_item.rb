class ReviewItem < ApplicationRecord
  belongs_to :review
  belongs_to :requirement

  has_many :review_comments, dependent: :destroy

  has_paper_trail

  enum :status, { pending: 0, approved: 1, rejected: 2, needs_changes: 3 }

  validates :status, presence: true
  validates :requirement_id, uniqueness: { scope: :review_id, message: "is already included in this review" }

  def snapshot_requirement!
    self.snapshot = {
      uid: requirement.uid,
      title: requirement.title,
      body: requirement.body,
      requirement_type: requirement.requirement_type,
      status: requirement.status,
      priority: requirement.priority,
      asil_level: requirement.asil_level,
      custom_attributes: requirement.custom_attributes,
      module_name: requirement.section&.requirement_module&.name,
      section_name: requirement.section&.name
    }
    save!
  end

  def decided?
    !pending?
  end

  def changed_since_snapshot?
    return false if snapshot.blank?

    requirement.title != snapshot["title"] ||
      requirement.body != snapshot["body"] ||
      requirement.requirement_type != snapshot["requirement_type"] ||
      requirement.status != snapshot["status"] ||
      requirement.priority != snapshot["priority"] ||
      requirement.asil_level != snapshot["asil_level"]
  end
end
