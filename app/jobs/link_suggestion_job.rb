class LinkSuggestionJob < ApplicationJob
  queue_as :ai_analysis

  retry_on LinkSuggester::Error, wait: :polynomially_longer, attempts: 3
  retry_on LlmService::TimeoutError, wait: 30.seconds, attempts: 2
  discard_on ActiveRecord::RecordNotFound

  def perform(requirement_id)
    requirement = Requirement.find(requirement_id)
    suggester = LinkSuggester.new
    result = suggester.suggest(requirement)

    store_result(requirement, "link_suggestion", result)
  end

  private

  def store_result(requirement, analysis_type, result)
    if defined?(AiAnalysisResult)
      AiAnalysisResult.store_result!(requirement, analysis_type, result)
    else
      Rails.logger.info("[LinkSuggestionJob] Suggestions complete for #{requirement.uid}: #{result[:suggestions].size} suggestions")
    end
  end
end
