class Review < ApplicationRecord
  belongs_to :project
  belongs_to :created_by, class_name: "User"

  has_many :review_items, dependent: :destroy
  has_many :review_participants, dependent: :destroy
  has_many :review_comments, through: :review_items
  has_many :requirements, through: :review_items
  has_many :participants, through: :review_participants, source: :user

  has_paper_trail

  enum :status, { draft: 0, open: 1, in_progress: 2, completed: 3, cancelled: 4 }

  validates :title, presence: true
  validates :status, presence: true
  validates :share_token, uniqueness: true, allow_nil: true

  VALID_TRANSITIONS = {
    "draft" => %w[open cancelled],
    "open" => %w[in_progress cancelled],
    "in_progress" => %w[completed cancelled],
    "completed" => [],
    "cancelled" => %w[draft]
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

  def snapshot_requirements!
    reqs = project.requirements.includes(:section, section: :requirement_module).order(:uid)
    self.baseline_snapshot = reqs.map do |req|
      {
        id: req.id,
        uid: req.uid,
        title: req.title,
        body: req.body,
        requirement_type: req.requirement_type,
        status: req.status,
        priority: req.priority,
        asil_level: req.asil_level,
        custom_attributes: req.custom_attributes,
        module_name: req.section&.requirement_module&.name,
        section_name: req.section&.name
      }
    end
    save!
  end

  def progress
    return { total: 0, decided: 0, percentage: 0 } if review_items.count.zero?

    total = review_items.count
    decided = review_items.where.not(status: :pending).count
    { total: total, decided: decided, percentage: (decided.to_f / total * 100).round }
  end

  def all_items_decided?
    review_items.exists? && review_items.where(status: :pending).none?
  end

  def auto_complete_if_all_decided!
    return false unless in_progress? && all_items_decided?

    transition_to(:completed)
  end

  def generate_share_token!
    loop do
      self.share_token = SecureRandom.urlsafe_base64(32)
      break unless Review.exists?(share_token: share_token)
    end
    save!
    share_token
  end

  def revoke_share_token!
    update!(share_token: nil)
  end

  def shared?
    share_token.present?
  end

  # Computes the overall outcome based on individual item decisions.
  # Returns :approved, :rejected, :needs_changes, or nil (if incomplete).
  def overall_outcome
    return nil unless review_items.exists?
    return nil if review_items.where(status: :pending).any?

    if review_items.where(status: :rejected).any?
      :rejected
    elsif review_items.where(status: :needs_changes).any?
      :needs_changes
    else
      :approved
    end
  end
end
