class ComplianceDashboardsController < ApplicationController
  before_action :set_project

  def show
    authorize @project, :show?

    @modules = @project.requirement_modules.includes(sections: :requirements).order(:position)
    @requirements = @project.requirements.includes(:section)
    @matrix = TraceabilityMatrix.new(@project)
    @coverage = @matrix.coverage_report

    compute_phase_coverage
    compute_expected_link_coverage
    compute_asil_distribution
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:project_id])
  end

  def compute_phase_coverage
    @phase_data = @modules.map do |mod|
      reqs = mod.sections.flat_map(&:requirements)
      req_ids = reqs.map(&:id)

      outgoing = TraceabilityLink.where(source_requirement_id: req_ids).count
      incoming = TraceabilityLink.where(target_requirement_id: req_ids).count

      linked_ids = Set.new
      TraceabilityLink.where(source_requirement_id: req_ids).pluck(:source_requirement_id).each { |id| linked_ids << id }
      TraceabilityLink.where(target_requirement_id: req_ids).pluck(:target_requirement_id).each { |id| linked_ids << id }

      linked_count = (linked_ids & req_ids.to_set).size
      total = reqs.size
      coverage_pct = total > 0 ? (linked_count.to_f / total * 100).round(1) : 0.0

      {
        module: mod,
        requirements_count: total,
        linked_count: linked_count,
        unlinked_count: total - linked_count,
        outgoing_links: outgoing,
        incoming_links: incoming,
        coverage_percentage: coverage_pct
      }
    end
  end

  def compute_expected_link_coverage
    @expected_link_data = []
    @template = detect_template

    return unless @template

    expected = @template.expected_links
    module_map = build_module_map

    expected.each do |exp|
      exp = exp.deep_symbolize_keys
      source_mod = module_map[exp[:source_module]]
      target_mod = module_map[exp[:target_module]]

      next unless source_mod && target_mod

      source_req_ids = source_mod.sections.flat_map(&:requirements).map(&:id)
      target_req_ids = target_mod.sections.flat_map(&:requirements).map(&:id)

      link_type_value = TraceabilityLink.link_types[exp[:link_type]]
      actual_count = if source_req_ids.any? && target_req_ids.any? && link_type_value
        TraceabilityLink
          .where(source_requirement_id: source_req_ids, target_requirement_id: target_req_ids, link_type: link_type_value)
          .count
      else
        0
      end

      source_count = source_req_ids.size
      target_count = target_req_ids.size
      expected_min = [ source_count, target_count ].min

      @expected_link_data << {
        source_module: source_mod,
        target_module: target_mod,
        link_type: exp[:link_type],
        description: exp[:description],
        actual_count: actual_count,
        source_requirements: source_count,
        target_requirements: target_count,
        expected_minimum: expected_min,
        met: actual_count >= expected_min && expected_min > 0,
        gap: [ expected_min - actual_count, 0 ].max
      }
    end
  end

  def compute_asil_distribution
    @asil_counts = @requirements.group(:asil_level).count
    @asil_total = @requirements.size
    @asil_data = Requirement.asil_levels.keys.map do |level|
      count = @asil_counts[level] || 0
      {
        level: level,
        count: count,
        percentage: @asil_total > 0 ? (count.to_f / @asil_total * 100).round(1) : 0.0
      }
    end
  end

  def detect_template
    return nil if @modules.empty?

    module_names = @modules.map(&:name)
    ComplianceTemplate.active.find do |t|
      template_names = t.phases.map { |p| p[:name] }
      (template_names - module_names).empty? && template_names.any?
    end
  end

  def build_module_map
    return {} unless @template

    phases = @template.phases
    modules_by_name = @modules.index_by(&:name)

    phases.each_with_object({}) do |phase, map|
      mod = modules_by_name[phase[:name]]
      map[phase[:key]] = mod if mod
    end
  end
end
