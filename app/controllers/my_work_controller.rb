class MyWorkController < ApplicationController
  def show
    return unless current_organization

    load_my_requirements
    load_my_change_sets
    load_my_reviews
    load_my_test_cases
    load_summary_counts
  end

  private

  def org_requirements
    Requirement.joins(section: { requirement_module: :project })
               .where(projects: { organization_id: current_organization.id })
  end

  def org_change_sets
    ChangeSet.joins(:project)
             .where(projects: { organization_id: current_organization.id })
  end

  def org_test_cases
    ::TestCase.joins(:project)
              .where(projects: { organization_id: current_organization.id })
  end

  def load_my_requirements
    base = org_requirements.where(requirements: { created_by_id: current_user.id })

    @requirements_status_filter = params[:req_status]
    filtered = base
    if @requirements_status_filter.present? && Requirement.statuses.key?(@requirements_status_filter)
      filtered = filtered.where(requirements: { status: @requirements_status_filter })
    end

    @my_requirements = filtered
      .includes(section: { requirement_module: :project })
      .order(updated_at: :desc)
      .limit(50)

    @my_requirements_count = base.count
    @my_requirements_status_counts = base.group(:status).count
  end

  def load_my_change_sets
    @my_created_change_sets = org_change_sets
      .where(created_by: current_user)
      .where.not(status: [:merged, :closed])
      .includes(:project, :change_set_changes, :change_set_approvals)
      .order(updated_at: :desc)
      .limit(20)

    @my_review_change_sets = ChangeSetApproval.joins(change_set: :project)
      .where(projects: { organization_id: current_organization.id })
      .where(change_set_approvals: { user_id: current_user.id, status: :pending })
      .where(change_sets: { status: [:in_review, :approved] })
      .includes(change_set: [:project, :created_by, :change_set_changes])
      .order("change_sets.created_at ASC")
      .limit(20)

    @my_created_count = org_change_sets.where(created_by: current_user).where.not(status: [:merged, :closed]).count
    @my_review_count = ChangeSetApproval.joins(change_set: :project)
      .where(projects: { organization_id: current_organization.id })
      .where(change_set_approvals: { user_id: current_user.id, status: :pending })
      .where(change_sets: { status: [:in_review, :approved] })
      .count
  end

  def load_my_reviews
    @my_formal_reviews = ReviewParticipant.joins(review: :project)
      .where(projects: { organization_id: current_organization.id })
      .where(review_participants: { user_id: current_user.id })
      .where(reviews: { status: [:open, :in_progress] })
      .includes(review: [:project, :created_by, :review_items])
      .order("reviews.updated_at DESC")
      .limit(10)
  end

  def load_my_test_cases
    @my_test_cases = org_test_cases
      .where(created_by: current_user)
      .includes(:project, :requirement)
      .order(updated_at: :desc)
      .limit(20)

    @my_test_cases_count = org_test_cases.where(created_by: current_user).count
    @my_test_cases_status_counts = org_test_cases.where(created_by: current_user).group(:status).count
  end

  def load_summary_counts
    @total_requirements = @my_requirements_count
    @total_change_sets = @my_created_count + @my_review_count
    @total_test_cases = @my_test_cases_count
  end
end
