class TraceabilityMatrix
  attr_reader :project

  def initialize(project)
    @project = project
  end

  def requirements
    project.requirements.order(:uid)
  end

  def links
    TraceabilityLink
      .joins(:source_requirement, :target_requirement)
      .where(source_requirement: { project_id: project.id })
      .where(target_requirement: { project_id: project.id })
  end

  def generate(link_types: nil, source_ids: nil, target_ids: nil)
    filtered_links = links
    filtered_links = filtered_links.where(link_type: link_types.map { |lt| TraceabilityLink.link_types[lt] }) if link_types.present?
    filtered_links = filtered_links.where(source_requirement_id: source_ids) if source_ids.present?
    filtered_links = filtered_links.where(target_requirement_id: target_ids) if target_ids.present?

    loaded_links = filtered_links.includes(:source_requirement, :target_requirement).to_a

    cells = {}
    source_ids_set = Set.new
    target_ids_set = Set.new

    loaded_links.each do |link|
      cell_key = "#{link.source_requirement_id}_#{link.target_requirement_id}"
      cells[cell_key] ||= []
      cells[cell_key] << link.link_type
      source_ids_set << link.source_requirement_id
      target_ids_set << link.target_requirement_id
    end

    rows = source_ids_set.any? ? Requirement.where(id: source_ids_set.to_a).order(:uid) : Requirement.none
    columns = target_ids_set.any? ? Requirement.where(id: target_ids_set.to_a).order(:uid) : Requirement.none

    {
      rows: rows,
      columns: columns,
      cells: cells,
      summary: {
        total_links: loaded_links.size,
        requirements_with_outgoing_links: source_ids_set.size,
        requirements_with_incoming_links: target_ids_set.size
      }
    }
  end

  def test_coverage_report
    all_requirements = requirements.to_a
    total = all_requirements.size

    return empty_test_coverage_report if total == 0

    req_ids = all_requirements.map(&:id)
    test_cases = TestCase.where(requirement_id: req_ids)

    # Requirements with at least one test case
    tested_req_ids = test_cases.distinct.pluck(:requirement_id).to_set
    untested_req_ids = req_ids - tested_req_ids.to_a

    # Group test cases by status
    status_counts = test_cases.group(:status).count
    by_status = {}
    TestCase.statuses.each_key do |s|
      by_status[s.to_sym] = status_counts.fetch(s, 0)
    end

    # Requirements with at least one passed/failed/not_run test case
    req_by_test_status = {}
    %i[passed failed not_run].each do |s|
      req_by_test_status[s] = test_cases.where(status: TestCase.statuses[s.to_s])
                                         .distinct.pluck(:requirement_id).size
    end

    {
      total_requirements: total,
      tested_requirements: tested_req_ids.size,
      untested_requirements: untested_req_ids.size,
      test_coverage_percentage: (tested_req_ids.size.to_f / total * 100).round(1),
      total_test_cases: test_cases.count,
      untested_requirement_ids: untested_req_ids,
      by_status: by_status,
      requirements_with_passed: req_by_test_status[:passed],
      requirements_with_failed: req_by_test_status[:failed],
      requirements_with_not_run: req_by_test_status[:not_run]
    }
  end

  def coverage_report
    all_requirements = requirements.to_a
    total = all_requirements.size

    return empty_coverage_report if total == 0

    all_links = links.to_a

    linked_ids = Set.new
    forward_ids = Set.new
    backward_ids = Set.new
    by_link_type = Hash.new { |h, k| h[k] = { count: 0, source_ids: Set.new, target_ids: Set.new } }

    all_links.each do |link|
      linked_ids << link.source_requirement_id
      linked_ids << link.target_requirement_id
      forward_ids << link.source_requirement_id
      backward_ids << link.target_requirement_id

      type_stats = by_link_type[link.link_type.to_sym]
      type_stats[:count] += 1
      type_stats[:source_ids] << link.source_requirement_id
      type_stats[:target_ids] << link.target_requirement_id
    end

    all_req_ids = all_requirements.map(&:id)
    unlinked_ids = all_req_ids - linked_ids.to_a

    {
      total_requirements: total,
      linked_requirements: linked_ids.size,
      unlinked_requirements: unlinked_ids.size,
      coverage_percentage: (linked_ids.size.to_f / total * 100).round(1),
      forward_coverage: (forward_ids.size.to_f / total * 100).round(1),
      backward_coverage: (backward_ids.size.to_f / total * 100).round(1),
      forward_count: forward_ids.size,
      backward_count: backward_ids.size,
      unlinked_requirement_ids: unlinked_ids,
      by_link_type: by_link_type.transform_values { |v|
        {
          count: v[:count],
          forward_count: v[:source_ids].size,
          backward_count: v[:target_ids].size,
          forward_percentage: (v[:source_ids].size.to_f / total * 100).round(1),
          backward_percentage: (v[:target_ids].size.to_f / total * 100).round(1)
        }
      }
    }
  end

  private

  def empty_test_coverage_report
    {
      total_requirements: 0,
      tested_requirements: 0,
      untested_requirements: 0,
      test_coverage_percentage: 0.0,
      total_test_cases: 0,
      untested_requirement_ids: [],
      by_status: TestCase.statuses.keys.each_with_object({}) { |s, h| h[s.to_sym] = 0 },
      requirements_with_passed: 0,
      requirements_with_failed: 0,
      requirements_with_not_run: 0
    }
  end

  def empty_coverage_report
    {
      total_requirements: 0,
      linked_requirements: 0,
      unlinked_requirements: 0,
      coverage_percentage: 0.0,
      forward_coverage: 0.0,
      backward_coverage: 0.0,
      forward_count: 0,
      backward_count: 0,
      unlinked_requirement_ids: [],
      by_link_type: {}
    }
  end
end
