class QualityAnalyzer
  class Error < StandardError; end

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a requirements quality analyst specializing in INCOSE (International Council on Systems Engineering) quality rules for requirements engineering. You analyze individual requirements and return structured quality assessments.

    Always respond with valid JSON in this exact format:
    {
      "overall_score": <integer 0-100>,
      "checks": [
        {
          "rule": "<rule_name>",
          "passed": <boolean>,
          "score": <integer 0-100>,
          "issues": ["<issue description>", ...],
          "suggestions": ["<improvement suggestion>", ...]
        }
      ],
      "summary": "<one-sentence summary of quality>"
    }

    The rules you must check are:
    1. **ambiguity** — Flag vague, subjective, or unmeasurable terms: "adequate", "appropriate", "as applicable", "as needed", "best", "effective", "efficient", "enough", "fast", "flexible", "good", "high", "low", "maximum", "minimum", "normal", "optimal", "poor", "reasonable", "significant", "sufficient", "suitable", "timely", "user-friendly", "etc.", "and/or". Each flagged term is an issue.
    2. **completeness** — The requirement must be self-contained and fully specify what is needed. Flag: missing conditions or triggers, missing performance criteria, undefined acronyms or terms, use of TBD/TBC/TBX placeholders, references to undefined external documents without specifics.
    3. **singularity** — Each requirement should express exactly one thought. Flag compound requirements using "and", "or", "also", "with", "as well as", "in addition" to combine distinct behaviors. A requirement that describes one behavior with multiple attributes is acceptable.
    4. **correctness** — The requirement must be grammatically correct and use active voice. Flag: passive voice constructions ("shall be provided", "is required to"), unclear pronoun references ("it", "this", "they" without clear antecedent), grammatical errors.
    5. **verifiability** — The requirement must be testable. Flag: subjective criteria that cannot be objectively measured, missing units of measurement for quantitative claims, unbounded ranges ("up to", "at least" without upper/lower bounds).
    6. **conformance** — The requirement should follow standard requirement structure: a clear subject, "shall" as the obligation keyword, and a clear predicate. Flag: use of "should", "will", "must", "can", "may" instead of "shall"; missing subject; wish-list language.
  PROMPT

  RULES = %w[ambiguity completeness singularity correctness verifiability conformance].freeze

  attr_reader :llm_service

  def initialize(llm_service: nil)
    @llm_service = llm_service || LlmService.new(timeout: 60)
  end

  def analyze(requirement)
    raise Error, "Requirement must have a title" if requirement.title.blank?

    prompt = build_prompt(requirement)
    response = llm_service.call(prompt, system_prompt: SYSTEM_PROMPT)
    normalize_response(response)
  rescue LlmService::Error => e
    raise Error, "Quality analysis failed: #{e.message}"
  end

  private

  def build_prompt(requirement)
    parts = []
    parts << "Analyze the following requirement for quality:\n"
    parts << "UID: #{requirement.uid}"
    parts << "Title: #{requirement.title}"
    parts << "Body: #{requirement.body}" if requirement.body.present?
    parts << "Type: #{requirement.requirement_type.humanize}"
    parts << "ASIL Level: #{requirement.asil_level.upcase}"
    parts << "\nReturn your analysis as JSON."
    parts.join("\n")
  end

  def normalize_response(response)
    return default_error_response("Empty response from LLM") if response.blank?

    # Handle plain text wrapper from LlmService
    if response.is_a?(Hash) && response.key?("text") && !response.key?("overall_score")
      return default_error_response("LLM returned non-structured response")
    end

    result = response.deep_symbolize_keys
    validate_and_normalize(result)
  rescue => e
    default_error_response("Failed to parse LLM response: #{e.message}")
  end

  def validate_and_normalize(result)
    {
      overall_score: clamp_score(result[:overall_score]),
      checks: normalize_checks(result[:checks]),
      summary: result[:summary].to_s.presence || "Analysis complete."
    }
  end

  def normalize_checks(checks)
    return default_checks unless checks.is_a?(Array)

    normalized = checks.map do |check|
      next unless check.is_a?(Hash)

      rule = check[:rule].to_s.downcase.strip
      next unless RULES.include?(rule)

      {
        rule: rule,
        passed: check[:passed] == true,
        score: clamp_score(check[:score]),
        issues: Array(check[:issues]).map(&:to_s),
        suggestions: Array(check[:suggestions]).map(&:to_s)
      }
    end.compact

    # Ensure all rules are represented
    covered_rules = normalized.map { |c| c[:rule] }
    RULES.each do |rule|
      unless covered_rules.include?(rule)
        normalized << { rule: rule, passed: true, score: 100, issues: [], suggestions: [] }
      end
    end

    normalized.sort_by { |c| RULES.index(c[:rule]) }
  end

  def default_checks
    RULES.map do |rule|
      { rule: rule, passed: true, score: 0, issues: ["Unable to analyze"], suggestions: [] }
    end
  end

  def default_error_response(message)
    {
      overall_score: 0,
      checks: RULES.map do |rule|
        { rule: rule, passed: false, score: 0, issues: [message], suggestions: [] }
      end,
      summary: message
    }
  end

  def clamp_score(score)
    score.to_i.clamp(0, 100)
  end
end
