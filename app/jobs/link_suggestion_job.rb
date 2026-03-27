class LinkSuggestionJob < ApplicationJob
  queue_as :ai_analysis

  retry_on LinkSuggester::Error, wait: :polynomially_longer, attempts: 3
  retry_on LlmService::TimeoutError, wait: 30.seconds, attempts: 2
  discard_on ActiveRecord::RecordNotFound

  def perform(requirement_id)
    requirement = Requirement.find(requirement_id)
    AiAnalysisResult.mark_running!(requirement, "link_suggestion")

    suggester = LinkSuggester.new
    result = suggester.suggest(requirement)

    AiAnalysisResult.store_result!(requirement, "link_suggestion", result)
  rescue LinkSuggester::Error, LlmService::TimeoutError => e
    AiAnalysisResult.store_failure!(requirement, "link_suggestion", e.message) if defined?(requirement) && requirement
    raise
  end
end
