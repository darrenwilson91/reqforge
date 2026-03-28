class TraceabilityGraphsController < ApplicationController
  before_action :set_project

  def show
    authorize @project, :show?

    matrix_service = TraceabilityMatrix.new(@project)
    @requirements = matrix_service.requirements.includes(:section => :requirement_module)
    @links = matrix_service.links.includes(:source_requirement, :target_requirement)
    @modules = @project.requirement_modules.order(:position)
    @coverage = matrix_service.coverage_report
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:project_id])
  end
end
