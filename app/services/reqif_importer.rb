require "rexml/document"

class ReqifImporter
  class Error < StandardError; end
  class ValidationError < Error; end
  class ParseError < Error; end

  VALID_REQUIREMENT_TYPES = Requirement.requirement_types.keys.freeze
  VALID_STATUSES = Requirement.statuses.keys.freeze
  VALID_PRIORITIES = Requirement.priorities.keys.freeze
  VALID_ASIL_LEVELS = Requirement.asil_levels.keys.freeze
  VALID_LINK_TYPES = TraceabilityLink.link_types.keys.freeze

  attr_reader :project, :user, :errors, :imported_requirements_count,
              :imported_links_count, :skipped_count

  def initialize(project, user)
    @project = project
    @user = user
    @errors = []
    @imported_requirements_count = 0
    @imported_links_count = 0
    @skipped_count = 0
  end

  def import(xml_content)
    reset_counters
    doc = parse_xml(xml_content)

    # Build lookup tables from datatypes for enum resolution
    @enum_lookup = build_enum_lookup(doc)

    # Build attribute definition lookup (identifier -> long-name slug)
    @attr_def_lookup = build_attr_def_lookup(doc)

    # Parse spec objects into requirement data
    spec_objects = parse_spec_objects(doc)
    validate_spec_objects(spec_objects)

    # Parse spec relations into link data
    spec_relations = parse_spec_relations(doc)

    # Parse hierarchy for module/section structure
    hierarchy = parse_hierarchy(doc)

    ActiveRecord::Base.transaction do
      # Import requirements
      @uid_to_requirement = {}
      import_requirements(spec_objects, hierarchy)

      if @errors.any?
        @imported_requirements_count = 0
        raise ActiveRecord::Rollback
      end
    end

    # Import links outside the requirement transaction —
    # link reference errors are non-blocking warnings
    if @errors.empty?
      import_links(spec_relations)
    end

    result
  end

  def import_file(file_path)
    content = File.read(file_path, encoding: "UTF-8")
    import(content)
  end

  private

  def reset_counters
    @errors = []
    @imported_requirements_count = 0
    @imported_links_count = 0
    @skipped_count = 0
  end

  def parse_xml(content)
    doc = REXML::Document.new(content)
    root = doc.root

    unless root&.name == "REQ-IF"
      raise ValidationError, "Invalid ReqIF document: missing REQ-IF root element"
    end

    doc
  rescue REXML::ParseException => e
    raise ParseError, "Invalid XML: #{e.message.lines.first&.strip}"
  end

  def build_enum_lookup(doc)
    lookup = {}
    doc.each_element("//ENUM-VALUE") do |ev|
      identifier = ev.attributes["IDENTIFIER"]
      # Try EMBEDDED-VALUE OTHER-CONTENT first (ReqForge format), then LONG-NAME
      embedded = ev.elements["PROPERTIES/EMBEDDED-VALUE"]
      value = if embedded
        embedded.attributes["OTHER-CONTENT"]
      else
        ev.attributes["LONG-NAME"]&.downcase&.tr(" ", "_")
      end
      lookup[identifier] = value if identifier && value
    end
    lookup
  end

  def build_attr_def_lookup(doc)
    lookup = {}

    # String attribute definitions
    doc.each_element("//ATTRIBUTE-DEFINITION-STRING") do |ad|
      lookup[ad.attributes["IDENTIFIER"]] = ad.attributes["LONG-NAME"]&.downcase&.tr(" ", "_")
    end

    # XHTML attribute definitions
    doc.each_element("//ATTRIBUTE-DEFINITION-XHTML") do |ad|
      lookup[ad.attributes["IDENTIFIER"]] = ad.attributes["LONG-NAME"]&.downcase&.tr(" ", "_")
    end

    # Enum attribute definitions
    doc.each_element("//ATTRIBUTE-DEFINITION-ENUMERATION") do |ad|
      lookup[ad.attributes["IDENTIFIER"]] = ad.attributes["LONG-NAME"]&.downcase&.tr(" ", "_")
    end

    lookup
  end

  def parse_spec_objects(doc)
    objects = []
    doc.each_element("//SPEC-OBJECTS/SPEC-OBJECT") do |so|
      attrs = parse_spec_object_attributes(so)
      attrs[:identifier] = so.attributes["IDENTIFIER"]
      objects << attrs
    end
    objects
  end

  def parse_spec_object_attributes(spec_object)
    attrs = {}

    spec_object.each_element("VALUES/*") do |val|
      case val.name
      when "ATTRIBUTE-VALUE-STRING"
        ref_el = val.elements["DEFINITION/ATTRIBUTE-DEFINITION-STRING-REF"]
        attr_name = resolve_attr_name(ref_el)
        attrs[attr_name] = val.attributes["THE-VALUE"] if attr_name
      when "ATTRIBUTE-VALUE-XHTML"
        ref_el = val.elements["DEFINITION/ATTRIBUTE-DEFINITION-XHTML-REF"]
        attr_name = resolve_attr_name(ref_el)
        if attr_name
          # Extract text content from XHTML div
          xhtml_div = val.elements["THE-VALUE/xhtml:div"] || val.elements["THE-VALUE"]
          attrs[attr_name] = extract_text_content(xhtml_div) if xhtml_div
        end
      when "ATTRIBUTE-VALUE-ENUMERATION"
        ref_el = val.elements["DEFINITION/ATTRIBUTE-DEFINITION-ENUMERATION-REF"]
        attr_name = resolve_attr_name(ref_el)
        if attr_name
          enum_ref = val.elements["VALUES/ENUM-VALUE-REF"]
          attrs[attr_name] = @enum_lookup[enum_ref&.text] if enum_ref
        end
      end
    end

    attrs
  end

  def resolve_attr_name(ref_element)
    return nil unless ref_element
    @attr_def_lookup[ref_element.text]
  end

  def extract_text_content(element)
    return "" unless element
    collect_text(element).strip
  end

  def collect_text(node)
    result = String.new
    node.each_child do |child|
      if child.is_a?(REXML::Text)
        result << child.value
      elsif child.is_a?(REXML::Element)
        result << collect_text(child)
      end
    end
    result
  end

  def validate_spec_objects(spec_objects)
    if spec_objects.empty?
      raise ValidationError, "ReqIF document contains no requirements (SPEC-OBJECTS)"
    end

    spec_objects.each_with_index do |obj, index|
      if obj["title"].blank?
        @errors << { object: index + 1, identifier: obj[:identifier], message: "Title is required" }
        @skipped_count += 1
      end
    end
  end

  def parse_spec_relations(doc)
    relations = []
    doc.each_element("//SPEC-RELATIONS/SPEC-RELATION") do |sr|
      source_ref = sr.elements["SOURCE/SPEC-OBJECT-REF"]&.text
      target_ref = sr.elements["TARGET/SPEC-OBJECT-REF"]&.text
      next unless source_ref && target_ref

      attrs = {}
      sr.each_element("VALUES/*") do |val|
        case val.name
        when "ATTRIBUTE-VALUE-ENUMERATION"
          ref_el = val.elements["DEFINITION/ATTRIBUTE-DEFINITION-ENUMERATION-REF"]
          attr_name = resolve_attr_name(ref_el)
          if attr_name == "link_type"
            enum_ref = val.elements["VALUES/ENUM-VALUE-REF"]
            attrs[:link_type] = @enum_lookup[enum_ref&.text] if enum_ref
          end
        when "ATTRIBUTE-VALUE-STRING"
          ref_el = val.elements["DEFINITION/ATTRIBUTE-DEFINITION-STRING-REF"]
          attr_name = resolve_attr_name(ref_el)
          attrs[:description] = val.attributes["THE-VALUE"] if attr_name == "description"
        end
      end

      relations << {
        source_ref: source_ref,
        target_ref: target_ref,
        link_type: attrs[:link_type],
        description: attrs[:description]
      }
    end
    relations
  end

  def parse_hierarchy(doc)
    hierarchy = {}
    # Map spec-object identifiers to module/section from SPEC-HIERARCHY
    doc.each_element("//SPECIFICATIONS/SPECIFICATION") do |spec|
      spec.each_element("CHILDREN/SPEC-HIERARCHY") do |mod_node|
        module_name = mod_node.attributes["LONG-NAME"] || "Imported"
        parse_hierarchy_children(mod_node, module_name, nil, hierarchy)
      end
    end
    hierarchy
  end

  def parse_hierarchy_children(node, module_name, section_name, hierarchy)
    node.each_element("CHILDREN/SPEC-HIERARCHY") do |child|
      obj_ref = child.elements["OBJECT/SPEC-OBJECT-REF"]&.text
      child_name = child.attributes["LONG-NAME"]

      if obj_ref
        # This is a requirement leaf node
        hierarchy[obj_ref] = {
          module_name: module_name,
          section_name: section_name || "Default"
        }
      elsif child_name
        # This is a section node — recurse
        parse_hierarchy_children(child, module_name, child_name, hierarchy)
      end
    end
  end

  def import_requirements(spec_objects, hierarchy)
    spec_objects.each_with_index do |obj, index|
      next if obj["title"].blank?
      import_requirement(obj, hierarchy, index)
    end
  end

  def import_requirement(obj, hierarchy, index)
    # Resolve module/section from hierarchy or spec object attributes
    location = hierarchy[obj[:identifier]] || {}
    module_name = location[:module_name] || obj["module_name"] || "Imported"
    section_name = location[:section_name] || obj["section_name"] || "Default"

    section = find_or_create_section(module_name, section_name)

    requirement = project.requirements.build(
      section: section,
      created_by: user,
      uid: obj["uid"].presence,
      title: obj["title"],
      body: obj["body"],
      requirement_type: normalize_enum(obj["requirement_type"], VALID_REQUIREMENT_TYPES, "functional"),
      status: normalize_enum(obj["status"], VALID_STATUSES, "draft"),
      priority: normalize_enum(obj["priority"], VALID_PRIORITIES, "must_have"),
      asil_level: normalize_enum(obj["asil_level"], VALID_ASIL_LEVELS, "qm")
    )

    if requirement.save
      @imported_requirements_count += 1
      @uid_to_requirement[obj[:identifier]] = requirement
    else
      @errors << { object: index + 1, identifier: obj[:identifier], message: requirement.errors.full_messages.join(", ") }
      @skipped_count += 1
    end
  end

  def import_links(spec_relations)
    spec_relations.each_with_index do |rel, index|
      source = @uid_to_requirement[rel[:source_ref]]
      target = @uid_to_requirement[rel[:target_ref]]

      unless source && target
        @errors << { relation: index + 1, message: "Source or target requirement not found for link" }
        next
      end

      link_type = normalize_enum(rel[:link_type], VALID_LINK_TYPES, "derives_from")

      link = TraceabilityLink.new(
        source_requirement: source,
        target_requirement: target,
        link_type: link_type,
        description: rel[:description].presence,
        created_by: user
      )

      if link.save
        @imported_links_count += 1
      else
        @errors << { relation: index + 1, message: link.errors.full_messages.join(", ") }
      end
    end
  end

  def normalize_enum(value, valid_values, default)
    return default if value.blank?
    normalized = value.downcase.strip.tr(" ", "_").tr("-", "_")
    valid_values.include?(normalized) ? normalized : default
  end

  def find_or_create_section(module_name, section_name)
    mod = project.requirement_modules.find_or_create_by!(name: module_name)
    mod.sections.find_or_create_by!(name: section_name)
  end

  def result
    {
      imported_requirements: @imported_requirements_count,
      imported_links: @imported_links_count,
      skipped: @skipped_count,
      errors: @errors,
      success: @errors.empty?
    }
  end
end
