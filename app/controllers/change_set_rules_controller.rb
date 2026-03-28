class ChangeSetRulesController < ApplicationController
  before_action :set_project

  def show
    @rule = @project.change_set_rule || @project.build_change_set_rule
    authorize @project, :update?
  end

  def update
    @rule = @project.change_set_rule || @project.build_change_set_rule
    authorize @project, :update?

    if @rule.update(rule_params)
      redirect_to project_change_set_rules_path(@project), notice: "Change set rules updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:project_id])
  end

  def rule_params
    params.require(:change_set_rule).permit(:min_approvals, :require_all_conversations_resolved, :auto_merge_on_approval)
  end
end
