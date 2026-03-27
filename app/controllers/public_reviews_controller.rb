class PublicReviewsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_current_organization

  layout "public_review"

  before_action :set_review_from_token

  def show
    @review_items = @review.review_items
      .includes(:requirement, :review_comments)
      .order("requirements.uid")
      .references(:requirements)
    @participants = @review.review_participants.includes(:user)
    @progress = @review.progress
    @outcome = @review.overall_outcome
  end

  def review_item
    @review_item = @review.review_items.includes(:requirement).find(params[:item_id])
    @diff = SnapshotDiff.new(@review_item)
    @diff_fields = @diff.compute

    @comments = @review_item.review_comments
      .top_level
      .includes(:user, :resolved_by, replies: [ :user, :resolved_by, replies: [ :user, :resolved_by ] ])
      .order(created_at: :asc)
  end

  private

  def set_review_from_token
    @review = Review.includes(:project, :created_by).find_by!(share_token: params[:token])
    @project = @review.project
  rescue ActiveRecord::RecordNotFound
    render plain: "Review not found or link has expired.", status: :not_found
  end
end
