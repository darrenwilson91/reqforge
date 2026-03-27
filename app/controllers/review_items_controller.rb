class ReviewItemsController < ApplicationController
  before_action :set_project
  before_action :set_review
  before_action :set_review_item, only: [ :show, :update_status ]

  def show
    authorize @review, :show?

    @diff = SnapshotDiff.new(@review_item)
    @diff_fields = @diff.compute

    @comments = @review_item.review_comments
      .top_level
      .includes(:user, :resolved_by, replies: [ :user, :resolved_by, replies: [ :user, :resolved_by ] ])
      .order(created_at: :asc)

    @participant = @review.review_participants.find_by(user: current_user)
  end

  def update_status
    authorize @review, :show?

    new_status = params[:status]
    unless ReviewItem.statuses.key?(new_status)
      redirect_to project_review_review_item_path(@project, @review, @review_item),
        alert: "Invalid status: #{new_status}" and return
    end

    # Only reviewers/approvers on active reviews can decide
    participant = @review.review_participants.find_by(user: current_user)
    unless participant&.can_decide? && @review.in_progress?
      redirect_to project_review_review_item_path(@project, @review, @review_item),
        alert: "You are not authorized to make decisions on this review item." and return
    end

    if @review_item.update(status: new_status)
      if @review.auto_complete_if_all_decided!
        redirect_to project_review_path(@project, @review),
          notice: "Item marked as #{new_status.humanize}. All items decided — review completed automatically."
      else
        redirect_to project_review_review_item_path(@project, @review, @review_item),
          notice: "Item marked as #{new_status.humanize}."
      end
    else
      redirect_to project_review_review_item_path(@project, @review, @review_item),
        alert: "Could not update status."
    end
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:project_id])
  end

  def set_review
    @review = @project.reviews.find(params[:review_id])
  end

  def set_review_item
    @review_item = @review.review_items.includes(:requirement).find(params[:id])
  end
end
