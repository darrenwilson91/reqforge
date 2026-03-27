require "rails_helper"

RSpec.describe "ReviewComments", type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user) }
  let(:reviewer_user) { create(:user) }
  let(:observer_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:project) { create(:project, organization: organization) }
  let(:req_module) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: req_module) }
  let(:requirement) { create(:requirement, project: project, section: section, created_by: admin_user) }
  let(:review) { create(:review, :in_progress, project: project, created_by: admin_user) }
  let(:review_item) do
    item = create(:review_item, review: review, requirement: requirement)
    item.snapshot_requirement!
    item
  end

  before do
    create(:membership, user: admin_user, organization: organization, role: :admin)
    create(:membership, user: reviewer_user, organization: organization, role: :author)
    create(:membership, user: observer_user, organization: organization, role: :reviewer)
    create(:membership, user: viewer_user, organization: organization, role: :viewer)
    create(:review_participant, review: review, user: admin_user, role: :author)
    create(:review_participant, review: review, user: reviewer_user, role: :reviewer)
    create(:review_participant, review: review, user: observer_user, role: :observer)
  end

  describe "POST /projects/:project_id/reviews/:review_id/review_items/:review_item_id/review_comments" do
    let(:comment_params) { { review_comment: { body: "This needs clarification" } } }

    context "as a reviewer participant" do
      before { sign_in reviewer_user }

      it "creates a comment" do
        expect {
          post project_review_review_item_review_comments_path(project, review, review_item), params: comment_params
        }.to change(ReviewComment, :count).by(1)
      end

      it "redirects to the review item with anchor" do
        post project_review_review_item_review_comments_path(project, review, review_item), params: comment_params
        comment = ReviewComment.last
        expect(response).to redirect_to(
          project_review_review_item_path(project, review, review_item, anchor: "comment-#{comment.id}")
        )
      end

      it "assigns the current user" do
        post project_review_review_item_review_comments_path(project, review, review_item), params: comment_params
        expect(ReviewComment.last.user).to eq(reviewer_user)
      end

      it "rejects blank body" do
        post project_review_review_item_review_comments_path(project, review, review_item),
          params: { review_comment: { body: "" } }
        expect(response).to redirect_to(project_review_review_item_path(project, review, review_item))
      end
    end

    context "creating a reply" do
      before { sign_in reviewer_user }

      let!(:parent_comment) { create(:review_comment, review_item: review_item, user: admin_user, body: "Original comment") }

      it "creates a threaded reply" do
        post project_review_review_item_review_comments_path(project, review, review_item),
          params: { review_comment: { body: "Replying to your point", parent_comment_id: parent_comment.id } }
        reply = ReviewComment.last
        expect(reply.parent_comment).to eq(parent_comment)
        expect(reply.body).to eq("Replying to your point")
      end
    end

    context "as author participant" do
      before { sign_in admin_user }

      it "allows commenting" do
        expect {
          post project_review_review_item_review_comments_path(project, review, review_item), params: comment_params
        }.to change(ReviewComment, :count).by(1)
      end
    end

    context "as observer participant" do
      before { sign_in observer_user }

      it "denies commenting" do
        post project_review_review_item_review_comments_path(project, review, review_item), params: comment_params
        expect(response).to redirect_to(project_review_review_item_path(project, review, review_item))
        expect(ReviewComment.count).to eq(0)
      end
    end

    context "as a non-participant viewer" do
      before { sign_in viewer_user }

      it "denies commenting" do
        post project_review_review_item_review_comments_path(project, review, review_item), params: comment_params
        expect(response).to redirect_to(project_review_review_item_path(project, review, review_item))
        expect(ReviewComment.count).to eq(0)
      end
    end
  end

  describe "PATCH resolve" do
    let!(:comment) { create(:review_comment, review_item: review_item, user: reviewer_user, body: "Check this") }

    context "as an authenticated member" do
      before { sign_in admin_user }

      it "resolves the comment" do
        patch resolve_project_review_review_item_review_comment_path(project, review, review_item, comment)
        comment.reload
        expect(comment.resolved?).to be true
        expect(comment.resolved_by).to eq(admin_user)
      end

      it "redirects with anchor" do
        patch resolve_project_review_review_item_review_comment_path(project, review, review_item, comment)
        expect(response).to redirect_to(
          project_review_review_item_path(project, review, review_item, anchor: "comment-#{comment.id}")
        )
      end
    end
  end

  describe "PATCH unresolve" do
    let!(:comment) do
      create(:review_comment, :resolved, review_item: review_item, user: reviewer_user, body: "Check this")
    end

    context "as an authenticated member" do
      before { sign_in admin_user }

      it "unresolves the comment" do
        patch unresolve_project_review_review_item_review_comment_path(project, review, review_item, comment)
        comment.reload
        expect(comment.resolved?).to be false
        expect(comment.resolved_by).to be_nil
      end
    end
  end
end
