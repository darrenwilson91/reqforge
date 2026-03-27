class ChangeSet < ApplicationRecord
  belongs_to :project
  belongs_to :created_by, class_name: "User"
  belongs_to :source_baseline, class_name: "Review", optional: true
  belongs_to :merged_by, class_name: "User", optional: true

  has_many :change_set_changes, dependent: :destroy
  has_many :change_set_approvals, dependent: :destroy
  has_many :approvers, through: :change_set_approvals, source: :user

  has_paper_trail

  enum :status, { draft: 0, open: 1, in_review: 2, approved: 3, merged: 4, closed: 5 }

  validates :title, presence: true
  validates :status, presence: true

  VALID_TRANSITIONS = {
    "draft" => %w[open closed],
    "open" => %w[in_review closed],
    "in_review" => %w[approved closed],
    "approved" => %w[merged closed],
    "merged" => [],
    "closed" => %w[draft]
  }.freeze

  def available_transitions
    VALID_TRANSITIONS.fetch(status, [])
  end

  def transition_to(new_status)
    new_status = new_status.to_s
    unless available_transitions.include?(new_status)
      errors.add(:status, "cannot transition from #{status} to #{new_status}")
      return false
    end
    update(status: new_status)
  end

  def merge!(user:, message: nil)
    return false unless approved?

    transaction do
      change_set_changes.find_each do |change|
        change.apply!
      end

      update!(
        status: :merged,
        merged_by: user,
        merged_at: Time.current,
        merge_commit_message: message
      )
    end
    true
  end

  def progress
    total = change_set_approvals.count
    return { total: 0, decided: 0, percentage: 0 } if total.zero?

    decided = change_set_approvals.where.not(status: :pending).count
    { total: total, decided: decided, percentage: (decided.to_f / total * 100).round }
  end

  def all_approved?
    change_set_approvals.exists? && change_set_approvals.where.not(status: :approved).none?
  end

  def any_changes_requested?
    change_set_approvals.where(status: :changes_requested).exists?
  end

  def changes_count
    { created: change_set_changes.where(change_type: :created).count,
      modified: change_set_changes.where(change_type: :modified).count,
      deleted: change_set_changes.where(change_type: :deleted).count }
  end
end
