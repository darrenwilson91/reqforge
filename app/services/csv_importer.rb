require "csv"

class CsvImporter
  class Error < StandardError; end
  class ValidationError < Error; end

  REQUIRED_COLUMNS = %w[title].freeze

  COLUMN_MAPPINGS = {
    "uid"              => :uid,
    "title"            => :title,
    "body"             => :body,
    "description"      => :body,
    "requirement_type" => :requirement_type,
    "type"             => :requirement_type,
    "status"           => :status,
    "priority"         => :priority,
    "asil_level"       => :asil_level,
    "asil"             => :asil_level,
    "module"           => :module_name,
    "module_name"      => :module_name,
    "section"          => :section_name,
    "section_name"     => :section_name
  }.freeze

  VALID_REQUIREMENT_TYPES = Requirement.requirement_types.keys.freeze
  VALID_STATUSES = Requirement.statuses.keys.freeze
  VALID_PRIORITIES = Requirement.priorities.keys.freeze
  VALID_ASIL_LEVELS = Requirement.asil_levels.keys.freeze

  attr_reader :project, :user, :errors, :imported_count, :skipped_count

  def initialize(project, user)
    @project = project
    @user = user
    @errors = []
    @imported_count = 0
    @skipped_count = 0
  end

  def import(csv_content)
    @errors = []
    @imported_count = 0
    @skipped_count = 0

    rows = parse_csv(csv_content)
    validate_headers(rows.first)

    ActiveRecord::Base.transaction do
      rows.each_with_index do |row, index|
        import_row(row, index + 2) # +2 for 1-based + header row
      end

      if @errors.any?
        @imported_count = 0
        raise ActiveRecord::Rollback
      end
    end

    {
      imported: @imported_count,
      skipped: @skipped_count,
      errors: @errors,
      success: @errors.empty?
    }
  end

  def import_file(file_path)
    content = File.read(file_path, encoding: "bom|utf-8")
    import(content)
  end

  private

  def parse_csv(content)
    # Strip UTF-8 BOM if present
    content = content.encode("UTF-8")
    content = content.sub("\xEF\xBB\xBF".force_encoding("UTF-8"), "")

    rows = CSV.parse(content, headers: true, skip_blanks: true)

    if rows.empty?
      raise ValidationError, "CSV file is empty or contains only headers"
    end

    # Store original headers for custom attribute preservation
    @original_headers = rows.first.headers.compact
    rows
  rescue CSV::MalformedCSVError => e
    raise ValidationError, "Invalid CSV format: #{e.message}"
  end

  def validate_headers(first_row)
    return unless first_row

    headers = first_row.headers.compact.map { |h| h.strip.downcase }
    mapped_headers = headers.filter_map { |h| COLUMN_MAPPINGS[h] }

    missing = REQUIRED_COLUMNS.reject { |col| mapped_headers.include?(COLUMN_MAPPINGS[col]) }

    if missing.any?
      raise ValidationError, "Missing required columns: #{missing.join(', ')}"
    end
  end

  def import_row(row, row_number)
    attrs = extract_attributes(row)

    if attrs[:title].blank?
      @errors << { row: row_number, message: "Title is required" }
      @skipped_count += 1
      return
    end

    section = find_or_create_section(attrs.delete(:module_name), attrs.delete(:section_name))

    # Handle custom attributes — any unmapped columns go into custom_attributes
    custom_attrs = extract_custom_attributes(row)

    requirement = project.requirements.build(
      section: section,
      created_by: user,
      custom_attributes: custom_attrs,
      **attrs
    )

    if requirement.save
      @imported_count += 1
    else
      @errors << { row: row_number, message: requirement.errors.full_messages.join(", ") }
      @skipped_count += 1
    end
  end

  def extract_attributes(row)
    attrs = {}

    row.each do |header, value|
      next if header.nil?
      key = header.strip.downcase
      mapped = COLUMN_MAPPINGS[key]
      next unless mapped

      attrs[mapped] = value&.strip
    end

    # Normalize enum values
    attrs[:requirement_type] = normalize_enum(attrs[:requirement_type], VALID_REQUIREMENT_TYPES, "functional")
    attrs[:status] = normalize_enum(attrs[:status], VALID_STATUSES, "draft")
    attrs[:priority] = normalize_enum(attrs[:priority], VALID_PRIORITIES, "must_have")
    attrs[:asil_level] = normalize_enum(attrs[:asil_level], VALID_ASIL_LEVELS, "qm")

    attrs
  end

  def normalize_enum(value, valid_values, default)
    return default if value.blank?
    normalized = value.downcase.strip.tr(" ", "_").tr("-", "_")
    valid_values.include?(normalized) ? normalized : default
  end

  def extract_custom_attributes(row)
    custom = {}
    known_headers = COLUMN_MAPPINGS.keys

    row.each do |header, value|
      next if header.nil?
      next if known_headers.include?(header.strip.downcase)
      next if value.blank?

      # Preserve original header casing from the CSV
      original_header = @original_headers&.find { |h| h.strip.downcase == header.strip.downcase } || header
      custom[original_header.strip] = value.strip
    end

    custom
  end

  def find_or_create_section(module_name, section_name)
    module_name = module_name.presence || "Imported"
    section_name = section_name.presence || "Default"

    mod = project.requirement_modules.find_or_create_by!(name: module_name)
    mod.sections.find_or_create_by!(name: section_name)
  end
end
