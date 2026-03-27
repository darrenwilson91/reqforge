class ReviewsController < ApplicationController
  before_action :set_project
  before_action :set_review, only: [ :show, :edit, :update, :destroy, :transition_status, :generate_share_token, :revoke_share_token ]

  def index
    authorize @project, :show?
    @reviews = @project.reviews
      .includes(:created_by, :review_items, :review_participants)
      .order(updated_at: :desc)
  end

  def show
    authorize @review
    @review_items = @review.review_items
      .includes(:requirement, :review_comments)
      .order("requirements.uid")
      .references(:requirements)
    @participants = @review.review_participants.includes(:user)
    @progress = @review.progress
    @outcome = @review.overall_outcome
  end

  def new
    @review = @project.reviews.build(created_by: current_user)
    authorize @review
    load_form_data
  end

  def create
    @review = @project.reviews.build(review_params)
    @review.created_by = current_user
    authorize @review

    Review.transaction do
      @review.save!

      # Create review items from selected requirement IDs
      requirement_ids = Array(params[:review][:requirement_ids]).reject(&:blank?)
      requirements = @project.requirements
        .includes(:section, section: :requirement_module)
        .where(id: requirement_ids)

      requirements.each do |req|
        item = @review.review_items.create!(requirement: req)
        item.snapshot_requirement!
      end

      # Snapshot the full project baseline
      @review.snapshot_requirements!

      # Add participants
      add_participants_from_params

      redirect_to project_review_path(@project, @review), notice: "Review created successfully."
    end
  rescue ActiveRecord::RecordInvalid
    load_form_data
    render :new, status: :unprocessable_entity
  end

  def edit
    authorize @review
    load_form_data
  end

  def update
    authorize @review
    if @review.update(review_params)
      redirect_to project_review_path(@project, @review), notice: "Review updated successfully."
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @review
    @review.destroy
    redirect_to project_reviews_path(@project), notice: "Review deleted successfully."
  end

  def transition_status
    authorize @review
    new_status = params[:status]

    if @review.transition_to(new_status)
      broadcast_review_status_change
      redirect_to project_review_path(@project, @review),
        notice: "Review status changed to #{new_status.humanize}."
    else
      redirect_to project_review_path(@project, @review),
        alert: @review.errors.full_messages.join(", ")
    end
  end

  def generate_share_token
    authorize @review, :update?
    @review.generate_share_token!
    redirect_to project_review_path(@project, @review),
      notice: "Share link generated. Anyone with the link can view this review."
  end

  def revoke_share_token
    authorize @review, :update?
    @review.revoke_share_token!
    redirect_to project_review_path(@project, @review),
      notice: "Share link revoked. The previous link will no longer work."
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:project_id])
  end

  def set_review
    @review = @project.reviews.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:title, :description)
  end

  def load_form_data
    @requirements = @project.requirements
      .includes(:section, section: :requirement_module)
      .order(:uid)
    @organization_members = current_organization.users
      .joins(:memberships)
      .where(memberships: { organization: current_organization })
      .where.not(id: current_user.id)
      .distinct
      .order(:first_name, :last_name)
  end

  def broadcast_review_status_change
    # Update the review status badge for other viewers
    Turbo::StreamsChannel.broadcast_update_to(
      @review,
      target: "review_status_#{@review.id}",
      html: @review.status.humanize
    )
  end

  def add_participants_from_params
    # Add the creator as author participant
    @review.review_participants.create!(user: current_user, role: :author)

    # Add selected reviewers
    reviewer_ids = Array(params[:review][:reviewer_ids]).reject(&:blank?)
    reviewer_ids.each do |user_id|
      member = current_organization.users.find_by(id: user_id)
      next unless member

      @review.review_participants.find_or_create_by!(user: member) do |p|
        p.role = :reviewer
      end
    end

    # Add selected approvers
    approver_ids = Array(params[:review][:approver_ids]).reject(&:blank?)
    approver_ids.each do |user_id|
      member = current_organization.users.find_by(id: user_id)
      next unless member

      @review.review_participants.find_or_create_by!(user: member) do |p|
        p.role = :approver
      end
    end
  end
end
