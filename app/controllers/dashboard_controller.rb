class DashboardController < ApplicationController
  def index
    return unless current_organization

    @projects = current_organization.projects
    @projects_count = @projects.count
    @requirements_count = Requirement.joins(section: { requirement_module: :project })
                                     .where(projects: { organization_id: current_organization.id })
                                     .count
    @active_reviews_count = Review.joins(:project)
                                  .where(projects: { organization_id: current_organization.id })
                                  .where(status: [:open, :in_progress])
                                  .count
    @team_members_count = current_organization.users.count

    @recent_projects = @projects.order(updated_at: :desc).limit(5)
    @recent_requirements = Requirement.joins(section: { requirement_module: :project })
                                      .where(projects: { organization_id: current_organization.id })
                                      .order(updated_at: :desc)
                                      .limit(5)
  end
end
