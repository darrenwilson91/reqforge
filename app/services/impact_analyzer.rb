class ImpactAnalyzer
  class Error < StandardError; end

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a requirements impact analysis expert specializing in automotive and safety-critical systems. When a requirement changes, you assess which downstream and related requirements are affected and how severely.

    Always respond with valid JSON in this exact format:
    {
      "impacts": [
        {
          "target_uid": "<UID of the affected requirement>",
          "severity": "<one of: high, medium, low>",
          "impact_type": "<one of: direct, indirect, potential>",
          "description": "<brief explanation of how this requirement is affected by the change>"
        }
      ],
      "summary": "<one-sentence overall impact assessment>",
      "risk_level": "<one of: critical, significant, moderate, minimal>"
    }

    Impact analysis guidelines:
    - **direct** impact: The affected requirement has an explicit traceability link to the changed requirement (derives_from, satisfies, verifies, implements, refines, parent_child). Changes to the source likely require changes to these requirements.
    - **indirect** impact: The affected requirement is connected through intermediate requirements (2+ hops) or shares system components/interfaces with the changed requirement.
    - **potential** impact: The affected requirement addresses similar functionality or system areas and should be reviewed for consistency, but may not require changes.

    Severity guidelines:
    - **high**: The affected requirement will almost certainly need to be updated. The change fundamentally alters the behavior, interface, or constraint that this requirement depends on.
    - **medium**: The affected requirement may need updates. The change alters assumptions or context that this requirement relies on.
    - **low**: The affected requirement should be reviewed but likely remains valid. The change is in a related area but may not affect this requirement's validity.

    Risk level guidelines:
    - **critical**: Changes affect safety requirements (ASIL-rated), multiple system layers, or core system interfaces. Requires formal review.
    - **significant**: Changes affect several downstream requirements or cross-module boundaries. Requires team review.
    - **moderate**: Changes affect a few related requirements within the same module. Standard review process sufficient.
    - **minimal**: Changes are isolated with little downstream effect. Quick review sufficient.

    Additional considerations:
    - Safety requirements (ASIL A-D) affected by the change should always be flagged as high severity.
    - If the changed requirement's ASIL level changes, all downstream safety requirements are directly impacted.
    - Cross-module impacts (requirements in different modules affected) increase the risk level.
    - Return an empty impacts array only if there are genuinely no affected requirements.
  PROMPT

  VALID_SEVERITIES = %w[high medium low].freeze
  VALID_IMPACT_TYPES = %w[direct indirect potential].freeze
  VALID_RISK_LEVELS = %w[critical significant moderate minimal].freeze

  MAX_RELATED_REQUIREMENTS = 100

  attr_reader :llm_service

  def initialize(llm_service: nil)
    @llm_service = llm_service || LlmService.new(timeout: 90)
  end

  def analyze(requirement, changes: nil)
    raise Error, "Requirement must have a title" if requirement.title.blank?

    related = find_related_requirements(requirement)
    return empty_result if related.empty?

    prompt = build_prompt(requirement, related, changes)
    response = llm_service.call(prompt, system_prompt: SYSTEM_PROMPT)
    normalize_response(response, related)
  rescue LlmService::Error => e
    raise Error, "Impact analysis failed: #{e.message}"
  end

  private

  def find_related_requirements(requirement)
    directly_linked = find_directly_linked(requirement)
    indirectly_linked = find_indirectly_linked(requirement, directly_linked)

    combined = (directly_linked + indirectly_linked).uniq(&:id)
    combined.reject { |r| r.id == requirement.id }
            .first(MAX_RELATED_REQUIREMENTS)
  end

  def find_directly_linked(requirement)
    link_ids = TraceabilityLink.links_for(requirement).pluck(:source_requirement_id, :target_requirement_id).flatten.uniq
    Requirement.where(id: link_ids)
               .where.not(id: requirement.id)
               .where.not(status: :obsolete)
               .includes(:section)
               .to_a
  end

  def find_indirectly_linked(requirement, directly_linked)
    return [] if directly_linked.empty?

    direct_ids = directly_linked.map(&:id)
    indirect_link_ids = TraceabilityLink
      .where(source_requirement_id: direct_ids)
      .or(TraceabilityLink.where(target_requirement_id: direct_ids))
      .pluck(:source_requirement_id, :target_requirement_id)
      .flatten
      .uniq

    Requirement.where(id: indirect_link_ids)
               .where.not(id: requirement.id)
               .where.not(id: direct_ids)
               .where.not(status: :obsolete)
               .includes(:section)
               .to_a
  end

  def build_prompt(requirement, related, changes)
    parts = []
    parts << "Analyze the impact of changes to this requirement:\n"
    parts << format_requirement(requirement, label: "CHANGED REQUIREMENT")

    if changes.present?
      parts << "\nChanges made:"
      changes.each do |field, (old_val, new_val)|
        parts << "  #{field}: \"#{old_val}\" → \"#{new_val}\""
      end
    end

    parts << "\n---\n"
    parts << "Related requirements that may be affected:\n"

    directly_linked_ids = find_directly_linked_ids(requirement)

    related.each_with_index do |req, index|
      relation = directly_linked_ids.include?(req.id) ? "DIRECTLY LINKED" : "INDIRECTLY RELATED"
      parts << format_requirement(req, label: "RELATED #{index + 1} (#{relation})")
      parts << ""
    end

    parts << "\nReturn your impact analysis as JSON. Consider link relationships, ASIL levels, and cross-module dependencies."
    parts.join("\n")
  end

  def find_directly_linked_ids(requirement)
    TraceabilityLink.links_for(requirement)
                    .pluck(:source_requirement_id, :target_requirement_id)
                    .flatten
                    .uniq
                    .reject { |id| id == requirement.id }
                    .to_set
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

  def normalize_response(response, related)
    return empty_result if response.blank?

    if response.is_a?(Hash) && response.key?("text") && !response.key?("impacts")
      return empty_result
    end

    result = response.deep_symbolize_keys
    {
      impacts: normalize_impacts(result[:impacts], related),
      summary: result[:summary].to_s.presence || "Impact analysis complete.",
      risk_level: normalize_risk_level(result[:risk_level])
    }
  rescue => e
    raise Error, "Failed to parse impact analysis: #{e.message}"
  end

  def normalize_impacts(impacts, related)
    return [] unless impacts.is_a?(Array)

    related_uids = related.map(&:uid).to_set

    impacts.filter_map do |impact|
      next unless impact.is_a?(Hash)

      uid = impact[:target_uid].to_s.strip
      next unless related_uids.include?(uid)

      severity = impact[:severity].to_s.downcase.strip
      next unless VALID_SEVERITIES.include?(severity)

      impact_type = impact[:impact_type].to_s.downcase.strip
      next unless VALID_IMPACT_TYPES.include?(impact_type)

      {
        target_uid: uid,
        severity: severity,
        impact_type: impact_type,
        description: impact[:description].to_s.presence || "May be affected by the change."
      }
    end.sort_by { |i| [VALID_SEVERITIES.index(i[:severity]), VALID_IMPACT_TYPES.index(i[:impact_type])] }
  end

  def normalize_risk_level(risk_level)
    level = risk_level.to_s.downcase.strip
    VALID_RISK_LEVELS.include?(level) ? level : "moderate"
  end

  def empty_result
    { impacts: [], summary: "No related requirements found.", risk_level: "minimal" }
  end
end
