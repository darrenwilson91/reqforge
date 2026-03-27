class ImpactAnalysisJob < ApplicationJob
  queue_as :ai_analysis

  retry_on ImpactAnalyzer::Error, wait: :polynomially_longer, attempts: 3
  retry_on LlmService::TimeoutError, wait: 30.seconds, attempts: 2
  discard_on ActiveRecord::RecordNotFound

  def perform(requirement_id, changes = nil)
    requirement = Requirement.find(requirement_id)
    AiAnalysisResult.mark_running!(requirement, "impact_analysis")

    analyzer = ImpactAnalyzer.new
    result = analyzer.analyze(requirement, changes: changes&.deep_symbolize_keys)

    AiAnalysisResult.store_result!(requirement, "impact_analysis", result)
    broadcast_notification(requirement)
  rescue ImpactAnalyzer::Error, LlmService::TimeoutError => e
    AiAnalysisResult.store_failure!(requirement, "impact_analysis", e.message) if defined?(requirement) && requirement
    raise
  end

  private

  def broadcast_notification(requirement)
    requirement.reload

    Turbo::StreamsChannel.broadcast_replace_to(
      requirement,
      target: "impact_notification_#{requirement.id}",
      partial: "requirements/impact_notification",
      locals: { requirement: requirement }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      requirement,
      target: "ai_analysis_panel",
      partial: "requirements/ai_panel",
      locals: { requirement: requirement, project: requirement.project }
    )
  rescue => e
    Rails.logger.warn("Impact analysis broadcast failed: #{e.message}")
  end
end
