class AiAnalysisResult < ApplicationRecord
  belongs_to :requirement

  ANALYSIS_TYPES = %w[quality_analysis link_suggestion impact_analysis].freeze

  enum :status, {
    pending: 0,
    running: 1,
    completed: 2,
    failed: 3
  }

  validates :analysis_type, presence: true, inclusion: { in: ANALYSIS_TYPES }
  validates :analysis_type, uniqueness: { scope: :requirement_id, message: "already exists for this requirement" }

  scope :for_type, ->(type) { where(analysis_type: type) }
  scope :latest_completed, -> { completed.order(completed_at: :desc) }
  scope :stale, ->(threshold = 24.hours) { where(completed_at: ...threshold.ago) }

  # Store a result from an AI service job, upserting by requirement + analysis_type
  def self.store_result!(requirement, analysis_type, result_data)
    record = find_or_initialize_by(requirement: requirement, analysis_type: analysis_type)
    record.update!(
      status: :completed,
      result_data: result_data,
      error_message: nil,
      completed_at: Time.current
    )
    record
  end

  # Mark an analysis as failed with an error message
  def self.store_failure!(requirement, analysis_type, error_message)
    record = find_or_initialize_by(requirement: requirement, analysis_type: analysis_type)
    record.update!(
      status: :failed,
      error_message: error_message,
      completed_at: Time.current
    )
    record
  end

  # Mark an analysis as running (in-progress)
  def self.mark_running!(requirement, analysis_type)
    record = find_or_initialize_by(requirement: requirement, analysis_type: analysis_type)
    record.update!(
      status: :running,
      error_message: nil
    )
    record
  end

  # Check if the result is stale (older than threshold)
  def stale?(threshold = 24.hours)
    return true unless completed_at
    completed_at < threshold.ago
  end

  # Convenience accessor for the quality score (quality_analysis only)
  def quality_score
    return nil unless analysis_type == "quality_analysis" && completed?
    result_data&.dig("overall_score") || result_data&.dig(:overall_score)
  end

  # Convenience accessor for suggested links count (link_suggestion only)
  def suggestions_count
    return nil unless analysis_type == "link_suggestion" && completed?
    suggestions = result_data&.dig("suggestions") || result_data&.dig(:suggestions)
    suggestions&.size || 0
  end

  # Convenience accessor for impact count (impact_analysis only)
  def impacts_count
    return nil unless analysis_type == "impact_analysis" && completed?
    impacts = result_data&.dig("impacts") || result_data&.dig(:impacts)
    impacts&.size || 0
  end
end
