class ImpactAnalysisJob < ApplicationJob
  queue_as :ai_analysis

  retry_on ImpactAnalyzer::Error, wait: :polynomially_longer, attempts: 3
  retry_on LlmService::TimeoutError, wait: 30.seconds, attempts: 2
  discard_on ActiveRecord::RecordNotFound

  def perform(requirement_id, changes = nil)
    requirement = Requirement.find(requirement_id)
    analyzer = ImpactAnalyzer.new
    result = analyzer.analyze(requirement, changes: changes&.deep_symbolize_keys)

    store_result(requirement, "impact_analysis", result)
  end

  private

  def store_result(requirement, analysis_type, result)
    if defined?(AiAnalysisResult)
      AiAnalysisResult.store_result!(requirement, analysis_type, result)
    else
      Rails.logger.info("[ImpactAnalysisJob] Analysis complete for #{requirement.uid}: #{result[:impacts].size} impacts, risk=#{result[:risk_level]}")
    end
  end
end
