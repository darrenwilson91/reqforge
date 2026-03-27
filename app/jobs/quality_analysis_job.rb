class QualityAnalysisJob < ApplicationJob
  queue_as :ai_analysis

  retry_on QualityAnalyzer::Error, wait: :polynomially_longer, attempts: 3
  retry_on LlmService::TimeoutError, wait: 30.seconds, attempts: 2
  discard_on ActiveRecord::RecordNotFound

  def perform(requirement_id)
    requirement = Requirement.find(requirement_id)
    analyzer = QualityAnalyzer.new
    result = analyzer.analyze(requirement)

    store_result(requirement, "quality_analysis", result)
  end

  private

  def store_result(requirement, analysis_type, result)
    if defined?(AiAnalysisResult)
      AiAnalysisResult.store_result!(requirement, analysis_type, result)
    else
      Rails.logger.info("[QualityAnalysisJob] Analysis complete for #{requirement.uid}: score=#{result[:overall_score]}")
    end
  end
end
