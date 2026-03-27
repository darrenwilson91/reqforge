require "open3"

class LlmService
  class Error < StandardError; end
  class TimeoutError < Error; end

  attr_reader :timeout

  # Path to homebrew binaries where claude CLI may be installed
  BREW_BIN_PATH = "/opt/homebrew/bin"

  def initialize(timeout: 30)
    @timeout = timeout
  end

  def call(prompt, format: nil, system_prompt: nil)
    args = build_args(prompt, format: format, system_prompt: system_prompt)
    stdout = execute_cli(args)
    parse_response(stdout)
  end

  private

  def build_args(prompt, format: nil, system_prompt: nil)
    args = ["claude", "-p", prompt]
    args.push("--system-prompt", system_prompt) if system_prompt
    args.push("--output-format", "json") if format == :json
    args
  end

  def execute_cli(args)
    env = { "PATH" => [BREW_BIN_PATH, ENV["PATH"]].join(":") }
    stdout, stderr, status = Open3.capture3(env, *args, timeout: timeout)

    unless status.success?
      message = "CLI exited with status #{status.exitstatus}"
      message += ": #{stderr.strip}" if stderr.present?
      raise Error, message
    end

    stdout
  rescue Timeout::Error
    raise TimeoutError, "LLM request timed out after #{timeout} seconds"
  rescue Errno::ENOENT
    raise Error, "claude CLI not found. Ensure it is installed and in PATH."
  end

  def parse_response(stdout)
    text = stdout.strip

    # Try parsing as direct JSON first
    return JSON.parse(text) if valid_json?(text)

    # Try extracting JSON object or array embedded in text
    if (match = text.match(/(\{[\s\S]*\})/))
      parsed = safe_parse(match[1])
      return parsed if parsed
    end

    if (match = text.match(/(\[[\s\S]*\])/))
      parsed = safe_parse(match[1])
      return parsed if parsed
    end

    # Fall back to plain text wrapper
    { "text" => text }
  end

  def valid_json?(str)
    return false if str.blank?
    first_char = str[0]
    (first_char == "{" || first_char == "[") && safe_parse(str).present?
  end

  def safe_parse(str)
    JSON.parse(str)
  rescue JSON::ParserError
    nil
  end
end
