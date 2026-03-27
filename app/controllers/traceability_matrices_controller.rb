class TraceabilityMatricesController < ApplicationController
  before_action :set_project

  def show
    authorize @project, :show?

    @matrix_service = TraceabilityMatrix.new(@project)

    filter_link_types = params[:link_types].present? ? params[:link_types].reject(&:blank?) : nil
    filter_source_module = params[:source_module].present? ? params[:source_module].to_i : nil
    filter_target_module = params[:target_module].present? ? params[:target_module].to_i : nil

    source_ids = nil
    target_ids = nil

    if filter_source_module
      source_ids = Requirement.joins(:section)
        .where(sections: { requirement_module_id: filter_source_module })
        .where(project_id: @project.id)
        .pluck(:id)
    end

    if filter_target_module
      target_ids = Requirement.joins(:section)
        .where(sections: { requirement_module_id: filter_target_module })
        .where(project_id: @project.id)
        .pluck(:id)
    end

    @matrix = @matrix_service.generate(
      link_types: filter_link_types,
      source_ids: source_ids,
      target_ids: target_ids
    )

    @coverage = @matrix_service.coverage_report
    @modules = @project.requirement_modules.order(:position)
    @all_requirements = @project.requirements.order(:uid)
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:project_id])
  end
end
