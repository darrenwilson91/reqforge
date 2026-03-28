class DashboardController < ApplicationController
  def index
    return unless current_organization

    @projects = current_organization.projects
    @projects_count = @projects.count
    @requirements_count = org_requirements.count
    @active_reviews_count = org_reviews.where(status: [:open, :in_progress]).count
    @team_members_count = current_organization.users.count

    @recent_projects = @projects.order(updated_at: :desc).limit(5)
    @recent_requirements = org_requirements.order(updated_at: :desc).limit(5)

    @is_manager = current_membership&.role.in?(%w[admin project_manager])

    if @is_manager
      load_manager_metrics
    else
      load_engineer_metrics
    end
  end

  private

  def org_requirements
    Requirement.joins(section: { requirement_module: :project })
               .where(projects: { organization_id: current_organization.id })
  end

  def org_reviews
    Review.joins(:project)
          .where(projects: { organization_id: current_organization.id })
  end

  def org_change_sets
    ChangeSet.joins(:project)
             .where(projects: { organization_id: current_organization.id })
  end

  def load_manager_metrics
    # Requirement status breakdown
    @requirement_status_counts = org_requirements.group(:status).count
    @approval_rate = calculate_approval_rate

    # Review velocity
    @reviews_total = org_reviews.count
    @reviews_completed = org_reviews.where(status: :completed).count

    # Change set metrics
    @open_change_sets = org_change_sets.where(status: [:draft, :open, :in_review, :approved]).count
    @merged_change_sets = org_change_sets.where(status: :merged).count

    # Overdue reviews: open/in_progress change sets older than 3 days
    @overdue_change_sets = org_change_sets
      .where(status: [:open, :in_review])
      .where("change_sets.created_at < ?", 3.days.ago)
      .includes(:project, :created_by)
      .order(created_at: :asc)
      .limit(5)

    # Reviewers with outstanding approvals
    @pending_approvals = ChangeSetApproval.joins(change_set: :project)
      .where(projects: { organization_id: current_organization.id })
      .where(change_set_approvals: { status: :pending })
      .where(change_sets: { status: [:in_review, :approved] })
      .includes(:user, change_set: :project)
      .group_by(&:user)
      .transform_values(&:count)
      .sort_by { |_, count| -count }
      .first(5)

    # Test case summary
    @test_cases_count = TestCase.joins(:project)
      .where(projects: { organization_id: current_organization.id })
      .count
    @test_cases_passed = TestCase.joins(:project)
      .where(projects: { organization_id: current_organization.id })
      .where(status: :passed)
      .count
    @test_cases_failed = TestCase.joins(:project)
      .where(projects: { organization_id: current_organization.id })
      .where(status: :failed)
      .count
  end

  def load_engineer_metrics
    # Requirements authored by current user
    @my_requirements = org_requirements
      .where(requirements: { created_by_id: current_user.id })
      .order(updated_at: :desc)
      .limit(10)
    @my_requirements_count = org_requirements
      .where(requirements: { created_by_id: current_user.id })
      .count

    # Pending reviews: change sets where I need to take action
    @my_pending_reviews = ChangeSetApproval.joins(change_set: :project)
      .where(projects: { organization_id: current_organization.id })
      .where(change_set_approvals: { user_id: current_user.id, status: :pending })
      .where(change_sets: { status: [:in_review, :approved] })
      .includes(change_set: [:project, :created_by])
      .order("change_sets.created_at ASC")
      .limit(10)

    # My change sets
    @my_change_sets = org_change_sets
      .where(created_by: current_user)
      .where.not(status: [:merged, :closed])
      .includes(:project)
      .order(updated_at: :desc)
      .limit(5)

    # Test cases authored by current user
    @my_test_cases = TestCase.joins(:project)
      .where(projects: { organization_id: current_organization.id })
      .where(created_by: current_user)
      .where.not(status: [:passed, :draft])
      .order(updated_at: :desc)
      .limit(5)
  end

  def calculate_approval_rate
    total = org_requirements.count
    return 0 if total.zero?

    approved = org_requirements.where(status: [:approved, :implemented, :verified]).count
    ((approved.to_f / total) * 100).round(0)
  end
end
