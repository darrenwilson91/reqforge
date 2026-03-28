class TraceabilityLink < ApplicationRecord
  has_paper_trail

  belongs_to :source_requirement, class_name: "Requirement"
  belongs_to :target_requirement, class_name: "Requirement"
  belongs_to :created_by, class_name: "User"

  enum :link_type, {
    derives_from: 0,
    satisfies: 1,
    verifies: 2,
    conflicts_with: 3,
    refines: 4,
    implements: 5,
    parent_child: 6
  }

  validates :link_type, presence: true
  validates :source_requirement_id, uniqueness: { scope: [:target_requirement_id, :link_type],
                                                   message: "already has this link type to the target requirement" }
  validates :confidence, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 },
                         allow_nil: true
  validate :no_self_links

  REVERSE_LINK_TYPES = {
    "derives_from" => "satisfies",
    "satisfies" => "derives_from",
    "verifies" => "derives_from",
    "conflicts_with" => "conflicts_with",
    "refines" => "derives_from",
    "implements" => "derives_from",
    "parent_child" => "parent_child"
  }.freeze

  def reverse_link_type
    REVERSE_LINK_TYPES[link_type]
  end

  def self.links_for(requirement)
    where(source_requirement: requirement)
      .or(where(target_requirement: requirement))
  end

  def other_requirement(from:)
    from == source_requirement ? target_requirement : source_requirement
  end

  private

  def no_self_links
    if source_requirement_id.present? && source_requirement_id == target_requirement_id
      errors.add(:target_requirement_id, "cannot be the same as source requirement")
    end
  end
end
