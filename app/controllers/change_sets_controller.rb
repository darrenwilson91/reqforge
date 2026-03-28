class ChangeSetsController < ApplicationController
  before_action :set_project
  before_action :set_change_set, only: [ :show, :edit, :update, :destroy, :transition_status, :approve, :request_changes, :merge, :activate, :deactivate ]

  def index
    authorize @project, :show?
    @change_sets = @project.change_sets
      .includes(:created_by, :change_set_changes, :change_set_approvals)
      .order(updated_at: :desc)
  end

  def show
    authorize @change_set
    @changes = @change_set.change_set_changes
      .includes(requirement: { section: :requirement_module })
      .order(:change_type, "requirements.uid")
      .references(:requirements)
    @approvals = @change_set.change_set_approvals.includes(:user)
    @changes_count = @change_set.changes_count
    @rule = @project.change_set_rule
    @progress = @change_set.progress
    @inline_comments = @change_set.change_set_comments.inline
      .includes(:user, :resolved_by, replies: [ :user, :resolved_by, replies: [ :user ] ])
      .top_level.order(:created_at)
      .group_by(&:change_set_change_id)
    @conversation_comments = @change_set.change_set_comments.conversation
      .includes(:user, :resolved_by, replies: [ :user, :resolved_by, replies: [ :user ] ])
      .top_level.order(:created_at)
    @unresolved_count = @change_set.change_set_comments.top_level.unresolved.count
  end

  def new
    @change_set = @project.change_sets.build(created_by: current_user)
    authorize @change_set
    load_form_data
  end

  def create
    @change_set = @project.change_sets.build(change_set_params)
    @change_set.created_by = current_user
    authorize @change_set

    if @change_set.save
      # Add selected reviewers as pending approvals
      add_reviewers_from_params

      # Auto-activate the new change set for editing
      session[:active_change_set_id] = @change_set.id

      redirect_to project_change_set_path(@project, @change_set), notice: "Change set created and activated. Edits to requirements will be recorded here."
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @change_set
    load_form_data
  end

  def update
    authorize @change_set
    if @change_set.update(change_set_params)
      redirect_to project_change_set_path(@project, @change_set), notice: "Change set updated successfully."
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @change_set
    @change_set.destroy
    redirect_to project_change_sets_path(@project), notice: "Change set deleted successfully."
  end

  def transition_status
    authorize @change_set
    new_status = params[:status]

    if @change_set.transition_to(new_status)
      # Clear active session if change set is now in a terminal state
      if new_status.in?(%w[closed]) && session[:active_change_set_id] == @change_set.id
        session.delete(:active_change_set_id)
      end
      redirect_to project_change_set_path(@project, @change_set),
        notice: "Change set status changed to #{new_status.humanize}."
    else
      redirect_to project_change_set_path(@project, @change_set),
        alert: @change_set.errors.full_messages.join(", ")
    end
  end

  def approve
    authorize @change_set, :approve?
    approval = @change_set.change_set_approvals.find_or_initialize_by(user: current_user)
    status = params[:approval_status] || "approved"

    approval.status = status
    approval.body = params[:body]

    if approval.save
      label = case status
      when "approved" then "approved"
      when "changes_requested" then "requested changes on"
      when "commented" then "commented on"
      else "reviewed"
      end
      redirect_to project_change_set_path(@project, @change_set),
        notice: "You #{label} this change set."
    else
      redirect_to project_change_set_path(@project, @change_set),
        alert: approval.errors.full_messages.join(", ")
    end
  end

  def request_changes
    authorize @change_set, :approve?
    approval = @change_set.change_set_approvals.find_or_initialize_by(user: current_user)
    approval.status = :changes_requested
    approval.body = params[:body]

    if approval.save
      redirect_to project_change_set_path(@project, @change_set),
        notice: "You requested changes on this change set."
    else
      redirect_to project_change_set_path(@project, @change_set),
        alert: approval.errors.full_messages.join(", ")
    end
  end

  def merge
    authorize @change_set, :merge?

    if @change_set.merge!(user: current_user, message: params[:merge_commit_message])
      session.delete(:active_change_set_id) if session[:active_change_set_id] == @change_set.id
      redirect_to project_change_set_path(@project, @change_set),
        notice: "Change set merged successfully. All changes have been applied."
    else
      redirect_to project_change_set_path(@project, @change_set),
        alert: "Cannot merge: change set must be in approved status."
    end
  end

  def activate
    authorize @change_set, :show?

    unless @change_set.status.in?(%w[draft open in_review])
      redirect_to project_change_set_path(@project, @change_set),
        alert: "Cannot activate a #{@change_set.status} change set."
      return
    end

    session[:active_change_set_id] = @change_set.id
    redirect_back fallback_location: project_requirements_path(@project),
      notice: "Now editing in change set \"#{@change_set.title}\". Requirement edits will be recorded here."
  end

  def deactivate
    authorize @change_set, :show?
    session.delete(:active_change_set_id)
    redirect_back fallback_location: project_change_set_path(@project, @change_set),
      notice: "Exited change set editing mode."
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:project_id])
  end

  def set_change_set
    @change_set = @project.change_sets.find(params[:id])
  end

  def change_set_params
    params.require(:change_set).permit(:title, :description)
  end

  def load_form_data
    @organization_members = current_organization.users
      .joins(:memberships)
      .where(memberships: { organization: current_organization })
      .where.not(id: current_user.id)
      .distinct
      .order(:first_name, :last_name)
  end

  def add_reviewers_from_params
    reviewer_ids = Array(params[:change_set][:reviewer_ids]).reject(&:blank?)
    reviewer_ids.each do |user_id|
      member = current_organization.users.find_by(id: user_id)
      next unless member

      @change_set.change_set_approvals.find_or_create_by!(user: member) do |a|
        a.status = :pending
      end
    end
  end
end
