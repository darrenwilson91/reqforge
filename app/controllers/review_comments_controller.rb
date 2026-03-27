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
      broadcast_new_comment(@comment)
      broadcast_review_item_card_update

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

    broadcast_comment_update(@comment)

    redirect_to project_review_review_item_path(@project, @review, @review_item, anchor: "comment-#{@comment.id}"),
      notice: "Comment resolved."
  end

  def unresolve
    authorize @review, :show?
    @comment.unresolve!

    broadcast_comment_update(@comment)

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

  def broadcast_new_comment(comment)
    if comment.top_level?
      # Append new top-level comment to the comments list
      Turbo::StreamsChannel.broadcast_append_to(
        @review_item,
        target: "comments_list_#{@review_item.id}",
        partial: "review_items/comment",
        locals: { comment: comment, depth: 0, project: @project, review: @review, review_item: @review_item, can_reply: false }
      )
      # Remove the empty state if it exists
      Turbo::StreamsChannel.broadcast_remove_to(
        @review_item,
        target: "comments_empty_#{@review_item.id}"
      )
    else
      # For replies, replace the parent comment to show the new reply in its thread
      parent = comment.parent_comment
      Turbo::StreamsChannel.broadcast_replace_to(
        @review_item,
        target: "comment-#{parent.id}",
        partial: "review_items/comment",
        locals: { comment: parent.reload, depth: parent.thread_depth, project: @project, review: @review, review_item: @review_item, can_reply: false }
      )
    end

    # Update comment count
    Turbo::StreamsChannel.broadcast_update_to(
      @review_item,
      target: "comment_count_#{@review_item.id}",
      html: "(#{@review_item.review_comments.count})"
    )
  end

  def broadcast_comment_update(comment)
    Turbo::StreamsChannel.broadcast_replace_to(
      @review_item,
      target: "comment-#{comment.id}",
      partial: "review_items/comment",
      locals: { comment: comment, depth: comment.thread_depth, project: @project, review: @review, review_item: @review_item, can_reply: false }
    )
  end

  def broadcast_review_item_card_update
    # Update the item card on the review show page (comment count changed)
    @review_item.reload
    Turbo::StreamsChannel.broadcast_replace_to(
      @review,
      target: "review_item_card_#{@review_item.id}",
      partial: "reviews/review_item_card",
      locals: { item: @review_item, project: @project, review: @review }
    )
  end
end
