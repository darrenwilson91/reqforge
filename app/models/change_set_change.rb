class ChangeSetChange < ApplicationRecord
  belongs_to :change_set
  belongs_to :requirement

  has_paper_trail

  enum :change_type, { created: 0, modified: 1, deleted: 2 }

  validates :change_type, presence: true
  validates :requirement_id, uniqueness: { scope: :change_set_id, message: "already has a change in this change set" }

  SNAPSHOT_ATTRIBUTES = %w[uid title body requirement_type status priority asil_level custom_attributes].freeze

  # Capture current requirement state into before_snapshot
  def snapshot_before!
    self.before_snapshot = build_snapshot
    save! if persisted?
  end

  # Capture current requirement state into after_snapshot
  def snapshot_after!
    self.after_snapshot = build_snapshot
    save! if persisted?
  end

  # Capture both snapshots at once (for new changes)
  def snapshot!
    self.before_snapshot = build_snapshot
    self.after_snapshot = build_snapshot
  end

  # Returns true if before and after snapshots differ on tracked attributes
  def any_changes?
    return true if created? || deleted?
    return false if before_snapshot.blank? || after_snapshot.blank?

    SNAPSHOT_ATTRIBUTES.any? do |attr|
      before_snapshot[attr] != after_snapshot[attr]
    end
  end

  # Returns a hash of changed fields with [old, new] values
  def changed_fields
    return {} if before_snapshot.blank? || after_snapshot.blank?

    SNAPSHOT_ATTRIBUTES.each_with_object({}) do |attr, changes|
      old_val = before_snapshot[attr]
      new_val = after_snapshot[attr]
      changes[attr] = [old_val, new_val] if old_val != new_val
    end
  end

  # Apply this change to the actual requirement
  def apply!
    case change_type
    when "created"
      # For created requirements, the requirement already exists — just ensure after_snapshot state
      apply_snapshot!(after_snapshot) if after_snapshot.present?
    when "modified"
      apply_snapshot!(after_snapshot) if after_snapshot.present?
    when "deleted"
      requirement.update!(status: :obsolete)
    end
  end

  private

  def build_snapshot
    return {} unless requirement

    snapshot = {}
    SNAPSHOT_ATTRIBUTES.each do |attr|
      snapshot[attr] = requirement.send(attr)
    end
    snapshot["module_name"] = requirement.section&.requirement_module&.name
    snapshot["section_name"] = requirement.section&.name
    snapshot
  end

  def apply_snapshot!(snapshot)
    attrs = snapshot.slice(*SNAPSHOT_ATTRIBUTES).except("uid")
    requirement.update!(attrs)
  end
end
