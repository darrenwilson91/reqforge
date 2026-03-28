class LinkSuggester
  class Error < StandardError; end

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a requirements traceability expert specializing in finding semantic relationships between requirements. Given a source requirement and a list of candidate requirements, you identify which candidates are most likely to have traceability relationships with the source.

    Always respond with valid JSON in this exact format:
    {
      "suggestions": [
        {
          "target_uid": "<UID of the candidate requirement>",
          "link_type": "<one of: derives_from, satisfies, verifies, conflicts_with, refines, implements, parent_child>",
          "confidence": <float 0.0 to 1.0>,
          "rationale": "<brief explanation of why this link is suggested>"
        }
      ]
    }

    Link type definitions:
    - **derives_from**: The source requirement is derived from the target (target is higher-level).
    - **satisfies**: The source requirement satisfies or fulfills the target requirement.
    - **verifies**: The source requirement verifies or tests the target requirement.
    - **conflicts_with**: The source and target requirements conflict or contradict each other.
    - **refines**: The source requirement refines or adds detail to the target requirement.
    - **implements**: The source requirement implements or realizes the target requirement.
    - **parent_child**: The source and target have a hierarchical parent-child relationship.

    Guidelines:
    - Only suggest links with confidence >= 0.3 — do not suggest weak or speculative links.
    - Consider semantic similarity, functional relationships, and hierarchical dependencies.
    - A safety requirement (ASIL-rated) that references the same system component as a functional requirement likely has a derives_from or satisfies relationship.
    - Requirements in different V-model phases (system req → software req → architecture → design → test) often have derives_from/satisfies/verifies chains.
    - If two requirements specify contradictory behaviors for the same component, flag as conflicts_with.
    - Return an empty suggestions array if no meaningful links are found.
    - Sort suggestions by confidence descending.
  PROMPT

  VALID_LINK_TYPES = %w[derives_from satisfies verifies conflicts_with refines implements parent_child].freeze

  MAX_CANDIDATES = 50

  attr_reader :llm_service

  def initialize(llm_service: nil)
    @llm_service = llm_service || LlmService.new(timeout: 90)
  end

  def suggest(requirement, candidates: nil)
    raise Error, "Requirement must have a title" if requirement.title.blank?

    candidates = resolve_candidates(requirement, candidates)
    return { suggestions: [] } if candidates.empty?

    prompt = build_prompt(requirement, candidates)
    response = llm_service.call(prompt, system_prompt: SYSTEM_PROMPT)
    normalize_response(response, candidates)
  rescue LlmService::Error => e
    raise Error, "Link suggestion failed: #{e.message}"
  end

  private

  def resolve_candidates(requirement, explicit_candidates)
    if explicit_candidates
      explicit_candidates.reject { |c| c.id == requirement.id }
    else
      requirement.project.requirements
        .where.not(id: requirement.id)
        .where.not(status: :obsolete)
        .includes(:section)
        .limit(MAX_CANDIDATES)
        .to_a
    end
  end

  def build_prompt(requirement, candidates)
    parts = []
    parts << "Find traceability links for this source requirement:\n"
    parts << format_requirement(requirement, label: "SOURCE")
    parts << "\n---\n"
    parts << "Candidate requirements to evaluate:\n"

    candidates.each_with_index do |candidate, index|
      parts << format_requirement(candidate, label: "CANDIDATE #{index + 1}")
      parts << ""
    end

    parts << "\nReturn your suggestions as JSON. Only suggest links with confidence >= 0.3."
    parts.join("\n")
  end

  def format_requirement(requirement, label:)
    lines = ["[#{label}]"]
    lines << "UID: #{requirement.uid}"
    lines << "Title: #{requirement.title}"
    lines << "Body: #{requirement.body}" if requirement.body.present?
    lines << "Type: #{requirement.requirement_type.humanize}"
    lines << "ASIL: #{requirement.asil_level.upcase}"
    lines << "Status: #{requirement.status.humanize}"
    if requirement.section
      lines << "Module: #{requirement.section.requirement_module.name}" if requirement.section.requirement_module
      lines << "Section: #{requirement.section.name}"
    end
    lines.join("\n")
  end

  def normalize_response(response, candidates)
    return { suggestions: [] } if response.blank?

    if response.is_a?(Hash) && response.key?("text") && !response.key?("suggestions")
      return { suggestions: [] }
    end

    result = response.deep_symbolize_keys
    suggestions = normalize_suggestions(result[:suggestions], candidates)
    { suggestions: suggestions }
  rescue => e
    raise Error, "Failed to parse link suggestions: #{e.message}"
  end

  def normalize_suggestions(suggestions, candidates)
    return [] unless suggestions.is_a?(Array)

    candidate_uids = candidates.map(&:uid).to_set

    suggestions.filter_map do |suggestion|
      next unless suggestion.is_a?(Hash)

      uid = suggestion[:target_uid].to_s.strip
      next unless candidate_uids.include?(uid)

      link_type = suggestion[:link_type].to_s.downcase.strip
      next unless VALID_LINK_TYPES.include?(link_type)

      confidence = normalize_confidence(suggestion[:confidence])
      next if confidence < 0.3

      {
        target_uid: uid,
        link_type: link_type,
        confidence: confidence,
        rationale: suggestion[:rationale].to_s.presence || "Semantic similarity detected."
      }
    end.sort_by { |s| -s[:confidence] }
  end

  def normalize_confidence(value)
    return 0.0 if value.nil?
    value.to_f.clamp(0.0, 1.0).round(2)
  end
end
