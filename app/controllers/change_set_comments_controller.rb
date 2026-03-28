class ChangeSetCommentsController < ApplicationController
  before_action :set_project
  before_action :set_change_set
  before_action :set_comment, only: [ :resolve, :unresolve ]

  def create
    @comment = @change_set.change_set_comments.build(comment_params)
    @comment.user = current_user

    if @comment.save
      redirect_to project_change_set_path(@project, @change_set, anchor: "comment-#{@comment.id}"),
        notice: "Comment added."
    else
      redirect_to project_change_set_path(@project, @change_set),
        alert: @comment.errors.full_messages.join(", ")
    end
  end

  def resolve
    @comment.resolve!(current_user)
    redirect_to project_change_set_path(@project, @change_set, anchor: "comment-#{@comment.id}"),
      notice: "Comment resolved."
  end

  def unresolve
    @comment.unresolve!
    redirect_to project_change_set_path(@project, @change_set, anchor: "comment-#{@comment.id}"),
      notice: "Comment reopened."
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:project_id])
  end

  def set_change_set
    @change_set = @project.change_sets.find(params[:change_set_id])
  end

  def set_comment
    @comment = @change_set.change_set_comments.find(params[:id])
  end

  def comment_params
    params.require(:change_set_comment).permit(:body, :change_set_change_id, :parent_comment_id)
  end
end
