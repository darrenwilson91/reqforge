class ChangeSetRule < ApplicationRecord
  belongs_to :project

  validates :project_id, uniqueness: true
  validates :min_approvals, presence: true,
                            numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 10 }

  def merge_eligible?(change_set)
    return false unless approval_count_met?(change_set)
    return false if require_all_conversations_resolved? && unresolved_conversations?(change_set)

    true
  end

  private

  def approval_count_met?(change_set)
    change_set.change_set_approvals.where(status: :approved).count >= min_approvals
  end

  def unresolved_conversations?(change_set)
    change_set.change_set_comments.top_level.unresolved.exists?
  end
end
