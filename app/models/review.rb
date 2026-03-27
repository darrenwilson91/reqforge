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
end
