class Requirement < ApplicationRecord
  include PgSearch::Model

  belongs_to :section
  belongs_to :project
  belongs_to :created_by, class_name: "User"

  has_many :outgoing_links, class_name: "TraceabilityLink", foreign_key: :source_requirement_id, dependent: :destroy
  has_many :incoming_links, class_name: "TraceabilityLink", foreign_key: :target_requirement_id, dependent: :destroy

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

  private

  def generate_uid
    return if uid.present?
    return unless project

    last_seq = project.requirements.maximum(:uid)&.then { |u| u.scan(/(\d+)\z/).flatten.first&.to_i } || 0
    self.uid = "#{project.prefix}-#{format('%04d', last_seq + 1)}"
  end
end
