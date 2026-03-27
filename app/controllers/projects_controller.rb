class ProjectsController < ApplicationController
  before_action :set_project, only: [ :show, :edit, :update, :destroy ]

  def index
    @projects = scoped_query(Project).order(updated_at: :desc)
  end

  def show
    @modules = @project.requirement_modules.order(:position).includes(sections: :requirements)
  end

  def new
    @project = build_scoped(Project)
  end

  def create
    @project = build_scoped(Project, project_params)

    if @project.save
      redirect_to project_path(@project), notice: "Project created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to project_path(@project), notice: "Project updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Project deleted successfully."
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description, :prefix, :status, :attribute_schema)
  end
end
