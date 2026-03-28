class TraceabilityLinksController < ApplicationController
  before_action :set_project
  before_action :set_traceability_link, only: [ :destroy ]

  def create
    @source_requirement = @project.requirements.find(params[:traceability_link][:source_requirement_id])
    @target_requirement = find_target_requirement

    @traceability_link = TraceabilityLink.new(traceability_link_params)
    @traceability_link.source_requirement = @source_requirement
    @traceability_link.target_requirement = @target_requirement
    @traceability_link.created_by = current_user
    authorize @traceability_link

    if @traceability_link.save
      redirect_to project_requirement_path(@project, @source_requirement),
        notice: "Traceability link created successfully."
    else
      redirect_to project_requirement_path(@project, @source_requirement),
        alert: @traceability_link.errors.full_messages.join(", ")
    end
  end

  def destroy
    authorize @traceability_link
    source = @traceability_link.source_requirement
    @traceability_link.destroy

    redirect_to project_requirement_path(@project, source),
      notice: "Traceability link removed."
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:project_id])
  end

  def set_traceability_link
    project_requirement_ids = @project.requirements.select(:id)
    @traceability_link = TraceabilityLink
      .where(source_requirement_id: project_requirement_ids)
      .or(TraceabilityLink.where(target_requirement_id: project_requirement_ids))
      .find(params[:id])
  end

  def find_target_requirement
    target_id = params[:traceability_link][:target_requirement_id]
    # Target can be in any project within the organization — cross-project links are valid
    Requirement.joins(:project)
      .where(projects: { organization_id: current_organization.id })
      .find(target_id)
  end

  def traceability_link_params
    params.require(:traceability_link).permit(:link_type, :description)
  end
end
