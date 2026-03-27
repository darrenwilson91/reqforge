class Requirement < ApplicationRecord
  include PgSearch::Model

  belongs_to :section
  belongs_to :project
  belongs_to :created_by, class_name: "User"

  has_many :outgoing_links, class_name: "TraceabilityLink", foreign_key: :source_requirement_id, dependent: :destroy
  has_many :incoming_links, class_name: "TraceabilityLink", foreign_key: :target_requirement_id, dependent: :destroy
  has_many :ai_analysis_results, dependent: :destroy

  has_paper_trail

  acts_as_list scope: :section_id

  multisearchable against: [ :uid, :title, :body ]

  pg_search_scope :search_by_text,
    against: { uid: "A", title: "A", body: "B" },
    using: {
      tsearch: { prefix: true, dictionary: "english" }
    }

  enum :requirement_type, {
    functional: 0,
    non_functional: 1,
    safety: 2,
    interface: 3,
    design_constraint: 4
  }

  enum :status, {
    draft: 0,
    in_review: 1,
    approved: 2,
    implemented: 3,
    verified: 4,
    obsolete: 5
  }

  enum :priority, {
    must_have: 0,
    should_have: 1,
    could_have: 2,
    wont_have: 3
  }

  enum :asil_level, {
    qm: 0,
    asil_a: 1,
    asil_b: 2,
    asil_c: 3,
    asil_d: 4
  }

  validates :uid, presence: true, uniqueness: true
  validates :title, presence: true

  before_validation :generate_uid, on: :create

  # Status workflow — defines valid transitions between statuses
  VALID_TRANSITIONS = {
    "draft"       => %w[in_review obsolete],
    "in_review"   => %w[approved draft obsolete],
    "approved"    => %w[implemented in_review obsolete],
    "implemented" => %w[verified approved obsolete],
    "verified"    => %w[implemented obsolete],
    "obsolete"    => %w[draft]
  }.freeze

  TRANSITION_LABELS = {
    "draft"       => { from_label: "Draft",       icon: "pencil" },
    "in_review"   => { from_label: "In Review",   icon: "eye" },
    "approved"    => { from_label: "Approved",     icon: "check" },
    "implemented" => { from_label: "Implemented",  icon: "code" },
    "verified"    => { from_label: "Verified",     icon: "shield" },
    "obsolete"    => { from_label: "Obsolete",     icon: "archive" }
  }.freeze

  # Returns the list of statuses this requirement can transition to
  def available_transitions
    VALID_TRANSITIONS.fetch(status, [])
  end

  # Attempts to transition to a new status; returns true on success
  def transition_to(new_status)
    unless available_transitions.include?(new_status)
      errors.add(:status, "cannot transition from #{status.humanize} to #{new_status.humanize}")
      return false
    end
    update(status: new_status)
  end

  # Returns a human-friendly label for a transition action
  def self.transition_action_label(from_status, to_status)
    case to_status
    when "draft"       then from_status == "obsolete" ? "Restore to Draft" : "Return to Draft"
    when "in_review"   then from_status == "approved" ? "Re-open Review" : "Submit for Review"
    when "approved"    then "Approve"
    when "implemented" then "Mark Implemented"
    when "verified"    then "Mark Verified"
    when "obsolete"    then "Mark Obsolete"
    else to_status.humanize
    end
  end

  private

  def generate_uid
    return if uid.present?
    return unless project

    last_seq = project.requirements.maximum(:uid)&.then { |u| u.scan(/(\d+)\z/).flatten.first&.to_i } || 0
    self.uid = "#{project.prefix}-#{format('%04d', last_seq + 1)}"
  end
end
