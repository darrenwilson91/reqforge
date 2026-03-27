class ProjectsController < ApplicationController
  before_action :set_project, only: [ :show, :edit, :update, :destroy ]

  def index
    @projects = scoped_query(Project).order(updated_at: :desc)
    authorize Project
  end

  def show
    authorize @project
    @modules = @project.requirement_modules.order(:position).includes(sections: :requirements)
  end

  def new
    @project = build_scoped(Project)
    authorize @project
  end

  def create
    @project = build_scoped(Project, project_params)
    authorize @project

    if @project.save
      apply_compliance_template(@project)
      redirect_to project_path(@project), notice: "Project created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @project
  end

  def update
    authorize @project
    if @project.update(project_params)
      redirect_to project_path(@project), notice: "Project updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @project
    @project.destroy
    redirect_to projects_path, notice: "Project deleted successfully."
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:id])
  end

  def apply_compliance_template(project)
    template_id = params[:compliance_template_id]
    return if template_id.blank?

    template = ComplianceTemplate.active.find_by(id: template_id)
    return unless template

    template.apply_to_project!(project)
  end

  def project_params
    permitted = params.require(:project).permit(:name, :description, :prefix, :status, :attribute_schema)
    if permitted[:attribute_schema].is_a?(String)
      permitted[:attribute_schema] = JSON.parse(permitted[:attribute_schema]) rescue []
    end
    permitted
  end
end
