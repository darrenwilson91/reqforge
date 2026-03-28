require "diff/lcs"

# Computes word-level diffs from PaperTrail version changesets
# for display in the requirement version history panel.
class VersionDiff
  DiffResult = Struct.new(:field, :old_value, :new_value, :diff_html, keyword_init: true)

  # Fields that are short/categorical — show old → new without word diff
  ENUM_FIELDS = %w[status requirement_type priority asil_level].freeze
  SKIP_FIELDS = %w[updated_at created_at position id section_id project_id created_by_id].freeze

  def initialize(version)
    @version = version
  end

  # Returns an array of DiffResult structs for each changed field
  def compute
    changeset = @version.changeset
    return [] if changeset.blank?

    changeset.filter_map do |field, (old_val, new_val)|
      next if SKIP_FIELDS.include?(field)

      if ENUM_FIELDS.include?(field)
        DiffResult.new(
          field: field,
          old_value: humanize_value(field, old_val),
          new_value: humanize_value(field, new_val),
          diff_html: nil
        )
      else
        old_str = old_val.to_s
        new_str = new_val.to_s
        DiffResult.new(
          field: field,
          old_value: old_str,
          new_value: new_str,
          diff_html: word_diff_html(old_str, new_str)
        )
      end
    end
  end

  private

  def humanize_value(field, value)
    return "—" if value.blank?
    value.to_s.humanize
  end

  # Generates HTML showing word-level additions and deletions
  def word_diff_html(old_text, new_text)
    return tag_addition(new_text) if old_text.blank?
    return tag_deletion(old_text) if new_text.blank?

    old_words = tokenize(old_text)
    new_words = tokenize(new_text)

    changes = Diff::LCS.sdiff(old_words, new_words)
    parts = changes.map do |change|
      case change.action
      when "="
        ERB::Util.html_escape(change.old_element)
      when "-"
        tag_deletion(change.old_element)
      when "+"
        tag_addition(change.new_element)
      when "!"
        tag_deletion(change.old_element) + tag_addition(change.new_element)
      end
    end

    parts.join(" ").html_safe
  end

  def tokenize(text)
    # Strip HTML tags for diffing, then split on whitespace
    ActionController::Base.helpers.strip_tags(text).split(/\s+/)
  end

  def tag_deletion(text)
    %(<span class="rf-diff-del">#{ERB::Util.html_escape(text)}</span>)
  end

  def tag_addition(text)
    %(<span class="rf-diff-add">#{ERB::Util.html_escape(text)}</span>)
  end
end
