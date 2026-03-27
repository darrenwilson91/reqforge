class QualityAnalysisJob < ApplicationJob
  queue_as :ai_analysis

  retry_on QualityAnalyzer::Error, wait: :polynomially_longer, attempts: 3
  retry_on LlmService::TimeoutError, wait: 30.seconds, attempts: 2
  discard_on ActiveRecord::RecordNotFound

  def perform(requirement_id)
    requirement = Requirement.find(requirement_id)
    AiAnalysisResult.mark_running!(requirement, "quality_analysis")

    analyzer = QualityAnalyzer.new
    result = analyzer.analyze(requirement)

    AiAnalysisResult.store_result!(requirement, "quality_analysis", result)
  rescue QualityAnalyzer::Error, LlmService::TimeoutError => e
    AiAnalysisResult.store_failure!(requirement, "quality_analysis", e.message) if defined?(requirement) && requirement
    raise
  end
end
