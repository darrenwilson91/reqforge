require "rexml/document"

class ReqifExporter
  REQIF_NAMESPACE = "http://www.omg.org/spec/ReqIF/20110401/reqif.xsd".freeze
  XSI_NAMESPACE = "http://www.w3.org/2001/XMLSchema-instance".freeze
  TOOL_ID = "ReqForge".freeze

  REQUIREMENT_TYPE_VALUES = %w[functional non_functional safety interface design_constraint].freeze
  STATUS_VALUES = %w[draft in_review approved implemented verified obsolete].freeze
  PRIORITY_VALUES = %w[must_have should_have could_have wont_have].freeze
  ASIL_LEVEL_VALUES = %w[qm asil_a asil_b asil_c asil_d].freeze
  LINK_TYPE_VALUES = %w[derives_from satisfies verifies conflicts_with refines implements parent_child].freeze

  attr_reader :project

  def initialize(project)
    @project = project
    @identifier_base = "reqforge-#{project.id}"
  end

  def export
    doc = build_document
    output = String.new
    formatter = REXML::Formatters::Pretty.new(2)
    formatter.compact = true
    output << %(<?xml version="1.0" encoding="UTF-8"?>\n)
    formatter.write(doc.root, output)
    output
  end

  def export_to_file(file_path)
    File.write(file_path, export, encoding: "UTF-8")
  end

  private

  def build_document
    doc = REXML::Document.new
    root = doc.add_element("REQ-IF", {
      "xmlns" => REQIF_NAMESPACE,
      "xmlns:xsi" => XSI_NAMESPACE
    })

    build_header(root)
    build_core_content(root)
    build_tool_extensions(root)

    doc
  end

  def build_header(root)
    header = root.add_element("THE-HEADER")
    req_if_header = header.add_element("REQ-IF-HEADER", {
      "IDENTIFIER" => identifier("header")
    })
    req_if_header.add_element("COMMENT").add_text("Exported from ReqForge")
    req_if_header.add_element("CREATION-TIME").add_text(Time.current.iso8601)
    req_if_header.add_element("REPOSITORY-ID").add_text("reqforge-project-#{project.id}")
    req_if_header.add_element("REQ-IF-TOOL-ID").add_text(TOOL_ID)
    req_if_header.add_element("REQ-IF-VERSION").add_text("1.2")
    req_if_header.add_element("SOURCE-TOOL-ID").add_text(TOOL_ID)
    req_if_header.add_element("TITLE").add_text(project.name)
  end

  def build_core_content(root)
    core = root.add_element("CORE-CONTENT")
    content = core.add_element("REQ-IF-CONTENT")

    build_datatypes(content)
    build_spec_types(content)
    build_spec_objects(content)
    build_spec_relations(content)
    build_specifications(content)
  end

  def build_datatypes(content)
    datatypes = content.add_element("DATATYPES")

    # String datatype
    datatypes.add_element("DATATYPE-DEFINITION-STRING", {
      "IDENTIFIER" => identifier("dt-string"),
      "LONG-NAME" => "String",
      "MAX-LENGTH" => "32000"
    })

    # XHTML datatype for rich text body
    datatypes.add_element("DATATYPE-DEFINITION-XHTML", {
      "IDENTIFIER" => identifier("dt-xhtml"),
      "LONG-NAME" => "XHTML"
    })

    # Enum datatypes
    build_enum_datatype(datatypes, "requirement-type", "Requirement Type", REQUIREMENT_TYPE_VALUES)
    build_enum_datatype(datatypes, "status", "Status", STATUS_VALUES)
    build_enum_datatype(datatypes, "priority", "Priority", PRIORITY_VALUES)
    build_enum_datatype(datatypes, "asil-level", "ASIL Level", ASIL_LEVEL_VALUES)
    build_enum_datatype(datatypes, "link-type", "Link Type", LINK_TYPE_VALUES)
  end

  def build_enum_datatype(parent, slug, long_name, values)
    dt = parent.add_element("DATATYPE-DEFINITION-ENUMERATION", {
      "IDENTIFIER" => identifier("dt-#{slug}"),
      "LONG-NAME" => long_name
    })
    specified_values = dt.add_element("SPECIFIED-VALUES")
    values.each_with_index do |value, index|
      specified_values.add_element("ENUM-VALUE", {
        "IDENTIFIER" => identifier("ev-#{slug}-#{value}"),
        "LONG-NAME" => value.tr("_", " ").titleize
      }).add_element("PROPERTIES").add_element("EMBEDDED-VALUE", {
        "KEY" => index.to_s,
        "OTHER-CONTENT" => value
      })
    end
  end

  def build_spec_types(content)
    spec_types = content.add_element("SPEC-TYPES")

    # SpecObject type for requirements
    req_type = spec_types.add_element("SPEC-OBJECT-TYPE", {
      "IDENTIFIER" => identifier("sot-requirement"),
      "LONG-NAME" => "Requirement"
    })
    spec_attrs = req_type.add_element("SPEC-ATTRIBUTES")

    add_string_attr_def(spec_attrs, "uid", "UID")
    add_string_attr_def(spec_attrs, "title", "Title")
    add_xhtml_attr_def(spec_attrs, "body", "Body")
    add_enum_attr_def(spec_attrs, "requirement-type", "Requirement Type", "requirement-type")
    add_enum_attr_def(spec_attrs, "status", "Status", "status")
    add_enum_attr_def(spec_attrs, "priority", "Priority", "priority")
    add_enum_attr_def(spec_attrs, "asil-level", "ASIL Level", "asil-level")
    add_string_attr_def(spec_attrs, "module-name", "Module Name")
    add_string_attr_def(spec_attrs, "section-name", "Section Name")

    # SpecRelation type for traceability links
    rel_type = spec_types.add_element("SPEC-RELATION-TYPE", {
      "IDENTIFIER" => identifier("srt-link"),
      "LONG-NAME" => "Traceability Link"
    })
    rel_attrs = rel_type.add_element("SPEC-ATTRIBUTES")
    add_enum_attr_def(rel_attrs, "link-type", "Link Type", "link-type")
    add_string_attr_def(rel_attrs, "description", "Description")

    # Specification type for document structure
    spec_types.add_element("SPECIFICATION-TYPE", {
      "IDENTIFIER" => identifier("st-specification"),
      "LONG-NAME" => "Requirements Specification"
    })
  end

  def add_string_attr_def(parent, slug, long_name)
    attr_def = parent.add_element("ATTRIBUTE-DEFINITION-STRING", {
      "IDENTIFIER" => identifier("ad-#{slug}"),
      "LONG-NAME" => long_name
    })
    type_ref = attr_def.add_element("TYPE")
    type_ref.add_element("DATATYPE-DEFINITION-STRING-REF").add_text(identifier("dt-string"))
  end

  def add_xhtml_attr_def(parent, slug, long_name)
    attr_def = parent.add_element("ATTRIBUTE-DEFINITION-XHTML", {
      "IDENTIFIER" => identifier("ad-#{slug}"),
      "LONG-NAME" => long_name
    })
    type_ref = attr_def.add_element("TYPE")
    type_ref.add_element("DATATYPE-DEFINITION-XHTML-REF").add_text(identifier("dt-xhtml"))
  end

  def add_enum_attr_def(parent, slug, long_name, datatype_slug)
    attr_def = parent.add_element("ATTRIBUTE-DEFINITION-ENUMERATION", {
      "IDENTIFIER" => identifier("ad-#{slug}"),
      "LONG-NAME" => long_name
    })
    type_ref = attr_def.add_element("TYPE")
    type_ref.add_element("DATATYPE-DEFINITION-ENUMERATION-REF").add_text(identifier("dt-#{datatype_slug}"))
  end

  def build_spec_objects(content)
    spec_objects = content.add_element("SPEC-OBJECTS")

    load_requirements.each do |requirement|
      build_spec_object(spec_objects, requirement)
    end
  end

  def build_spec_object(parent, requirement)
    spec_obj = parent.add_element("SPEC-OBJECT", {
      "IDENTIFIER" => identifier("so-#{requirement.id}"),
      "LONG-NAME" => requirement.uid,
      "LAST-CHANGE" => requirement.updated_at.iso8601
    })

    values = spec_obj.add_element("VALUES")

    add_string_value(values, "uid", requirement.uid)
    add_string_value(values, "title", requirement.title)
    add_xhtml_value(values, "body", requirement.body || "")
    add_enum_value(values, "requirement-type", "requirement-type", requirement.requirement_type)
    add_enum_value(values, "status", "status", requirement.status)
    add_enum_value(values, "priority", "priority", requirement.priority)
    add_enum_value(values, "asil-level", "asil-level", requirement.asil_level)
    add_string_value(values, "module-name", requirement.section.requirement_module.name)
    add_string_value(values, "section-name", requirement.section.name)

    type_el = spec_obj.add_element("TYPE")
    type_el.add_element("SPEC-OBJECT-TYPE-REF").add_text(identifier("sot-requirement"))
  end

  def add_string_value(parent, attr_slug, value)
    attr_val = parent.add_element("ATTRIBUTE-VALUE-STRING", {
      "THE-VALUE" => value.to_s
    })
    def_ref = attr_val.add_element("DEFINITION")
    def_ref.add_element("ATTRIBUTE-DEFINITION-STRING-REF").add_text(identifier("ad-#{attr_slug}"))
  end

  def add_xhtml_value(parent, attr_slug, value)
    attr_val = parent.add_element("ATTRIBUTE-VALUE-XHTML")
    the_value = attr_val.add_element("THE-VALUE")
    xhtml_div = the_value.add_element("xhtml:div", {
      "xmlns:xhtml" => "http://www.w3.org/1999/xhtml"
    })
    xhtml_div.add_text(value.to_s)
    def_ref = attr_val.add_element("DEFINITION")
    def_ref.add_element("ATTRIBUTE-DEFINITION-XHTML-REF").add_text(identifier("ad-#{attr_slug}"))
  end

  def add_enum_value(parent, attr_slug, datatype_slug, value)
    attr_val = parent.add_element("ATTRIBUTE-VALUE-ENUMERATION")
    enum_values = attr_val.add_element("VALUES")
    enum_values.add_element("ENUM-VALUE-REF").add_text(identifier("ev-#{datatype_slug}-#{value}"))
    def_ref = attr_val.add_element("DEFINITION")
    def_ref.add_element("ATTRIBUTE-DEFINITION-ENUMERATION-REF").add_text(identifier("ad-#{attr_slug}"))
  end

  def build_spec_relations(content)
    spec_relations = content.add_element("SPEC-RELATIONS")

    load_links.each do |link|
      build_spec_relation(spec_relations, link)
    end
  end

  def build_spec_relation(parent, link)
    spec_rel = parent.add_element("SPEC-RELATION", {
      "IDENTIFIER" => identifier("sr-#{link.id}"),
      "LONG-NAME" => "#{link.source_requirement.uid} -> #{link.target_requirement.uid}",
      "LAST-CHANGE" => link.updated_at.iso8601
    })

    values = spec_rel.add_element("VALUES")
    add_enum_value(values, "link-type", "link-type", link.link_type)
    add_string_value(values, "description", link.description || "")

    type_el = spec_rel.add_element("TYPE")
    type_el.add_element("SPEC-RELATION-TYPE-REF").add_text(identifier("srt-link"))

    source_el = spec_rel.add_element("SOURCE")
    source_el.add_element("SPEC-OBJECT-REF").add_text(identifier("so-#{link.source_requirement_id}"))

    target_el = spec_rel.add_element("TARGET")
    target_el.add_element("SPEC-OBJECT-REF").add_text(identifier("so-#{link.target_requirement_id}"))
  end

  def build_specifications(content)
    specifications = content.add_element("SPECIFICATIONS")

    spec = specifications.add_element("SPECIFICATION", {
      "IDENTIFIER" => identifier("spec-#{project.id}"),
      "LONG-NAME" => project.name,
      "LAST-CHANGE" => project.updated_at.iso8601
    })

    type_el = spec.add_element("TYPE")
    type_el.add_element("SPECIFICATION-TYPE-REF").add_text(identifier("st-specification"))

    children = spec.add_element("CHILDREN")
    build_spec_hierarchy(children)
  end

  def build_spec_hierarchy(parent)
    modules = project.requirement_modules
      .includes(sections: [ :child_sections, :requirements ])
      .order(:position)

    modules.each do |mod|
      mod_node = parent.add_element("SPEC-HIERARCHY", {
        "IDENTIFIER" => identifier("sh-mod-#{mod.id}"),
        "LONG-NAME" => mod.name
      })

      mod_children = mod_node.add_element("CHILDREN")

      mod.sections.where(parent_section_id: nil).order(:position).each do |section|
        build_section_hierarchy(mod_children, section)
      end
    end
  end

  def build_section_hierarchy(parent, section)
    section_node = parent.add_element("SPEC-HIERARCHY", {
      "IDENTIFIER" => identifier("sh-sec-#{section.id}"),
      "LONG-NAME" => section.name
    })

    section_children = section_node.add_element("CHILDREN")

    # Add requirements as leaf nodes
    section.requirements.order(:position).each do |requirement|
      req_node = section_children.add_element("SPEC-HIERARCHY", {
        "IDENTIFIER" => identifier("sh-req-#{requirement.id}")
      })
      obj_ref = req_node.add_element("OBJECT")
      obj_ref.add_element("SPEC-OBJECT-REF").add_text(identifier("so-#{requirement.id}"))
    end

    # Add child sections recursively
    section.child_sections.order(:position).each do |child|
      build_section_hierarchy(section_children, child)
    end
  end

  def build_tool_extensions(root)
    root.add_element("TOOL-EXTENSIONS")
  end

  def load_requirements
    @requirements ||= project.requirements
      .includes(section: :requirement_module)
      .order("requirement_modules.name ASC, sections.name ASC, requirements.position ASC")
      .references(:sections, :requirement_modules)
  end

  def load_links
    @links ||= begin
      req_ids = project.requirements.pluck(:id)
      TraceabilityLink
        .where(source_requirement_id: req_ids, target_requirement_id: req_ids)
        .includes(:source_requirement, :target_requirement)
    end
  end

  def identifier(suffix)
    "#{@identifier_base}-#{suffix}"
  end
end
