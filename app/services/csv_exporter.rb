require "csv"

class CsvExporter
  STANDARD_COLUMNS = %w[
    uid
    title
    body
    requirement_type
    status
    priority
    asil_level
    module_name
    section_name
  ].freeze

  attr_reader :project

  def initialize(project)
    @project = project
  end

  def export
    requirements = load_requirements
    custom_attribute_keys = collect_custom_attribute_keys(requirements)
    headers = STANDARD_COLUMNS + custom_attribute_keys

    CSV.generate do |csv|
      csv << headers
      requirements.each do |requirement|
        csv << build_row(requirement, custom_attribute_keys)
      end
    end
  end

  def export_to_file(file_path)
    File.write(file_path, export, encoding: "UTF-8")
  end

  private

  def load_requirements
    project.requirements
      .includes(section: :requirement_module)
      .order("requirement_modules.name ASC, sections.name ASC, requirements.position ASC")
      .references(:sections, :requirement_modules)
  end

  def collect_custom_attribute_keys(requirements)
    requirements
      .filter_map { |r| r.custom_attributes&.keys }
      .flatten
      .uniq
      .sort
  end

  def build_row(requirement, custom_attribute_keys)
    row = [
      requirement.uid,
      requirement.title,
      requirement.body,
      requirement.requirement_type,
      requirement.status,
      requirement.priority,
      requirement.asil_level,
      requirement.section.requirement_module.name,
      requirement.section.name
    ]

    custom_attribute_keys.each do |key|
      row << requirement.custom_attributes&.dig(key)
    end

    row
  end
end
