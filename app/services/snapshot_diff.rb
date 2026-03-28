require "diff/lcs"

# Compares a ReviewItem's snapshot to the current requirement state
# and generates word-level diff HTML for changed fields.
class SnapshotDiff
  DiffField = Struct.new(:field, :label, :snapshot_value, :current_value, :diff_html, :changed, keyword_init: true)

  TEXT_FIELDS = %w[title body].freeze
  ENUM_FIELDS = %w[requirement_type status priority asil_level].freeze
  META_FIELDS = %w[module_name section_name].freeze

  FIELD_LABELS = {
    "uid" => "UID",
    "title" => "Title",
    "body" => "Description",
    "requirement_type" => "Type",
    "status" => "Status",
    "priority" => "Priority",
    "asil_level" => "ASIL Level",
    "module_name" => "Module",
    "section_name" => "Section"
  }.freeze

  def initialize(review_item)
    @review_item = review_item
    @snapshot = review_item.snapshot || {}
    @requirement = review_item.requirement
  end

  def compute
    return [] if @snapshot.blank?

    fields = []

    # UID (read-only, but show for reference)
    fields << build_field("uid", @snapshot["uid"], @requirement.uid)

    # Text fields — word-level diff
    TEXT_FIELDS.each do |field|
      snap_val = @snapshot[field].to_s
      curr_val = @requirement.send(field).to_s
      fields << build_text_field(field, snap_val, curr_val)
    end

    # Enum fields — old → new badge
    ENUM_FIELDS.each do |field|
      snap_val = @snapshot[field].to_s
      curr_val = @requirement.send(field).to_s
      fields << build_field(field, snap_val, curr_val)
    end

    # Meta fields
    META_FIELDS.each do |field|
      snap_val = @snapshot[field].to_s
      curr_val = current_meta_value(field)
      fields << build_field(field, snap_val, curr_val)
    end

    fields
  end

  def changed_fields
    compute.select(&:changed)
  end

  def any_changes?
    compute.any?(&:changed)
  end

  private

  def build_field(field, snap_val, curr_val)
    changed = snap_val.to_s.strip != curr_val.to_s.strip
    DiffField.new(
      field: field,
      label: FIELD_LABELS[field] || field.humanize,
      snapshot_value: humanize_value(field, snap_val),
      current_value: humanize_value(field, curr_val),
      diff_html: nil,
      changed: changed
    )
  end

  def build_text_field(field, snap_val, curr_val)
    changed = snap_val.strip != curr_val.strip
    diff_html = changed ? word_diff_html(snap_val, curr_val) : nil

    DiffField.new(
      field: field,
      label: FIELD_LABELS[field] || field.humanize,
      snapshot_value: snap_val,
      current_value: curr_val,
      diff_html: diff_html,
      changed: changed
    )
  end

  def humanize_value(field, value)
    return "—" if value.blank?

    if ENUM_FIELDS.include?(field)
      value.to_s.humanize
    else
      value.to_s
    end
  end

  def current_meta_value(field)
    case field
    when "module_name"
      @requirement.section&.requirement_module&.name.to_s
    when "section_name"
      @requirement.section&.name.to_s
    else
      ""
    end
  end

  def word_diff_html(old_text, new_text)
    old_clean = strip_html(old_text)
    new_clean = strip_html(new_text)

    return tag_addition(new_clean) if old_clean.blank?
    return tag_deletion(old_clean) if new_clean.blank?

    old_words = old_clean.split(/\s+/)
    new_words = new_clean.split(/\s+/)

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
        tag_deletion(change.old_element) + " " + tag_addition(change.new_element)
      end
    end

    parts.join(" ").html_safe
  end

  def strip_html(text)
    ActionController::Base.helpers.strip_tags(text.to_s)
  end

  def tag_deletion(text)
    %(<span class="rf-diff-del">#{ERB::Util.html_escape(text)}</span>)
  end

  def tag_addition(text)
    %(<span class="rf-diff-add">#{ERB::Util.html_escape(text)}</span>)
  end
end
