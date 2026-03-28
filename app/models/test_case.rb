class TestCase < ApplicationRecord
  belongs_to :project
  belongs_to :requirement, optional: true
  belongs_to :created_by, class_name: "User"

  has_paper_trail

  enum :test_type, {
    unit: 0,
    integration: 1,
    system: 2,
    acceptance: 3,
    safety: 4
  }

  enum :status, {
    draft: 0,
    ready: 1,
    passed: 2,
    failed: 3,
    blocked: 4,
    not_run: 5
  }

  enum :priority, {
    must_have: 0,
    should_have: 1,
    could_have: 2,
    wont_have: 3
  }

  validates :uid, presence: true, uniqueness: true
  validates :title, presence: true

  before_validation :generate_uid, on: :create

  private

  def generate_uid
    return if uid.present?
    return unless project

    last_seq = project.test_cases.maximum(:uid)&.then { |u| u.scan(/(\d+)\z/).flatten.first&.to_i } || 0
    self.uid = "#{project.prefix}-TC-#{format('%03d', last_seq + 1)}"
  end
end
