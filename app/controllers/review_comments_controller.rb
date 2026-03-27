class ReviewCommentsController < ApplicationController
  before_action :set_project
  before_action :set_review
  before_action :set_review_item
  before_action :set_comment, only: [ :resolve, :unresolve ]

  def create
    authorize @review, :show?

    participant = @review.review_participants.find_by(user: current_user)
    unless participant&.can_comment?
      redirect_to project_review_review_item_path(@project, @review, @review_item),
        alert: "You are not authorized to comment on this review." and return
    end

    @comment = @review_item.review_comments.build(comment_params)
    @comment.user = current_user

    if @comment.save
      redirect_to project_review_review_item_path(@project, @review, @review_item, anchor: "comment-#{@comment.id}"),
        notice: "Comment added."
    else
      redirect_to project_review_review_item_path(@project, @review, @review_item),
        alert: @comment.errors.full_messages.join(", ")
    end
  end

  def resolve
    authorize @review, :show?
    @comment.resolve!(current_user)
    redirect_to project_review_review_item_path(@project, @review, @review_item, anchor: "comment-#{@comment.id}"),
      notice: "Comment resolved."
  end

  def unresolve
    authorize @review, :show?
    @comment.unresolve!
    redirect_to project_review_review_item_path(@project, @review, @review_item, anchor: "comment-#{@comment.id}"),
      notice: "Comment reopened."
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:project_id])
  end

  def set_review
    @review = @project.reviews.find(params[:review_id])
  end

  def set_review_item
    @review_item = @review.review_items.find(params[:review_item_id])
  end

  def set_comment
    @comment = @review_item.review_comments.find(params[:id])
  end

  def comment_params
    params.require(:review_comment).permit(:body, :parent_comment_id)
  end
end
