class RequirementGenerator
  class Error < StandardError; end

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a requirements engineering expert specializing in automotive and safety-critical systems. Given a natural language description of desired functionality, you generate well-structured, INCOSE-compliant requirement drafts.

    Always respond with valid JSON in this exact format:
    {
      "requirements": [
        {
          "title": "<concise requirement title>",
          "body": "<full requirement text using 'shall' as the obligation keyword>",
          "requirement_type": "<one of: functional, non_functional, safety, interface, design_constraint>",
          "priority": "<one of: must_have, should_have, could_have, wont_have>",
          "asil_level": "<one of: qm, asil_a, asil_b, asil_c, asil_d>",
          "rationale": "<brief explanation of why this requirement was generated>"
        }
      ]
    }

    Requirement writing rules (INCOSE guidelines):
    1. **Use "shall"** as the obligation keyword. Never use "should", "will", "must", "can", or "may".
    2. **One requirement per thought** — do not combine distinct behaviors with "and", "or", or "also".
    3. **Use active voice** — the subject shall perform the action, not "the action shall be performed".
    4. **Be specific and measurable** — include units, ranges, and thresholds where applicable.
    5. **Avoid ambiguity** — do not use vague terms like "adequate", "appropriate", "fast", "user-friendly".
    6. **Be self-contained** — each requirement should be understandable without referencing others.
    7. **Make it verifiable** — each requirement must be testable with a clear pass/fail criterion.

    Requirement type guidelines:
    - **functional**: Describes what the system shall do (behavior, processing, data handling).
    - **non_functional**: Describes performance, reliability, availability, scalability constraints.
    - **safety**: Requirements with safety implications — assign appropriate ASIL levels.
    - **interface**: Defines interactions between system components or external systems.
    - **design_constraint**: Constraints on architecture, technology, or implementation approach.

    ASIL level guidelines:
    - **qm**: Quality Management — no specific safety integrity requirement.
    - **asil_a**: Lowest automotive safety integrity level.
    - **asil_b**: Moderate automotive safety integrity level.
    - **asil_c**: High automotive safety integrity level.
    - **asil_d**: Highest automotive safety integrity level — for the most critical safety functions.
    - Default to "qm" unless the description explicitly mentions safety, hazards, or risk.

    Priority guidelines:
    - **must_have**: Essential for the system to function. Core functionality.
    - **should_have**: Important but the system can work without it temporarily.
    - **could_have**: Desirable enhancement that improves user experience.
    - **wont_have**: Acknowledged but explicitly excluded from current scope.
    - Default to "must_have" for safety requirements, "should_have" for others unless context suggests otherwise.

    Additional guidelines:
    - Break complex descriptions into multiple focused requirements.
    - If the description mentions safety or hazards, generate at least one safety requirement.
    - Include relevant non-functional requirements (performance, reliability) when implied by the description.
    - Generate between 1 and 10 requirements depending on the complexity of the description.
  PROMPT

  VALID_REQUIREMENT_TYPES = %w[functional non_functional safety interface design_constraint].freeze
  VALID_PRIORITIES = %w[must_have should_have could_have wont_have].freeze
  VALID_ASIL_LEVELS = %w[qm asil_a asil_b asil_c asil_d].freeze

  MAX_REQUIREMENTS = 10

  attr_reader :llm_service

  def initialize(llm_service: nil)
    @llm_service = llm_service || LlmService.new(timeout: 90)
  end

  def generate(description, context: {})
    raise Error, "Description cannot be blank" if description.blank?

    prompt = build_prompt(description, context)
    response = llm_service.call(prompt, system_prompt: SYSTEM_PROMPT)
    normalize_response(response)
  rescue LlmService::Error => e
    raise Error, "Requirement generation failed: #{e.message}"
  end

  private

  def build_prompt(description, context)
    parts = []
    parts << "Generate structured requirements from this description:\n"
    parts << description

    if context[:project_name].present?
      parts << "\n---\nProject context:"
      parts << "Project: #{context[:project_name]}"
      parts << "Domain: #{context[:domain]}" if context[:domain].present?
    end

    if context[:existing_types].present?
      parts << "\nExisting requirement types in this project: #{context[:existing_types].join(', ')}"
    end

    if context[:module_name].present?
      parts << "Target module: #{context[:module_name]}"
    end

    if context[:section_name].present?
      parts << "Target section: #{context[:section_name]}"
    end

    parts << "\nReturn your generated requirements as JSON. Follow INCOSE guidelines strictly."
    parts.join("\n")
  end

  def normalize_response(response)
    return { requirements: [] } if response.blank?

    if response.is_a?(Hash) && response.key?("text") && !response.key?("requirements")
      return { requirements: [] }
    end

    result = response.deep_symbolize_keys
    { requirements: normalize_requirements(result[:requirements]) }
  rescue => e
    raise Error, "Failed to parse generated requirements: #{e.message}"
  end

  def normalize_requirements(requirements)
    return [] unless requirements.is_a?(Array)

    requirements.first(MAX_REQUIREMENTS).filter_map do |req|
      next unless req.is_a?(Hash)
      next if req[:title].to_s.strip.blank?

      requirement_type = normalize_enum(req[:requirement_type], VALID_REQUIREMENT_TYPES, "functional")
      priority = normalize_enum(req[:priority], VALID_PRIORITIES, "should_have")
      asil_level = normalize_enum(req[:asil_level], VALID_ASIL_LEVELS, "qm")

      {
        title: req[:title].to_s.strip,
        body: req[:body].to_s.strip.presence || req[:title].to_s.strip,
        requirement_type: requirement_type,
        priority: priority,
        asil_level: asil_level,
        rationale: req[:rationale].to_s.presence || "Generated from natural language description."
      }
    end
  end

  def normalize_enum(value, valid_values, default)
    normalized = value.to_s.downcase.strip
    valid_values.include?(normalized) ? normalized : default
  end
end
