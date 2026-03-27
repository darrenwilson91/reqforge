require "rails_helper"

RSpec.describe "ReviewItems", type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user) }
  let(:reviewer_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:project) { create(:project, organization: organization) }
  let(:req_module) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: req_module) }
  let(:requirement) do
    create(:requirement, project: project, section: section, created_by: admin_user,
      title: "Shall handle braking", body: "The system shall handle braking input")
  end
  let(:review) { create(:review, :open, project: project, created_by: admin_user) }
  let!(:review_item) do
    item = create(:review_item, review: review, requirement: requirement)
    item.snapshot_requirement!
    item
  end

  before do
    create(:membership, user: admin_user, organization: organization, role: :admin)
    create(:membership, user: reviewer_user, organization: organization, role: :author)
    create(:membership, user: viewer_user, organization: organization, role: :viewer)
    create(:review_participant, review: review, user: admin_user, role: :author)
    create(:review_participant, review: review, user: reviewer_user, role: :reviewer)
  end

  describe "GET /projects/:project_id/reviews/:review_id/review_items/:id" do
    it "redirects unauthenticated users" do
      get project_review_review_item_path(project, review, review_item)
      expect(response).to redirect_to(new_user_session_path)
    end

    context "when authenticated" do
      before { sign_in admin_user }

      it "renders the review item detail page" do
        get project_review_review_item_path(project, review, review_item)
        expect(response).to have_http_status(:success)
      end

      it "shows the requirement UID" do
        get project_review_review_item_path(project, review, review_item)
        expect(response.body).to include(requirement.uid)
      end

      it "shows the requirement title" do
        get project_review_review_item_path(project, review, review_item)
        expect(response.body).to include("Shall handle braking")
      end

      it "shows breadcrumbs" do
        get project_review_review_item_path(project, review, review_item)
        expect(response.body).to include(project.name)
        expect(response.body).to include(review.title)
      end

      it "shows diff fields" do
        get project_review_review_item_path(project, review, review_item)
        expect(response.body).to include("Requirement Changes")
        expect(response.body).to include("Title")
        expect(response.body).to include("Description")
        expect(response.body).to include("Status")
      end

      it "shows unchanged badges when nothing changed" do
        get project_review_review_item_path(project, review, review_item)
        expect(response.body).to include("Unchanged")
      end

      context "when requirement has changed since snapshot" do
        before { requirement.update!(title: "Updated braking requirement") }

        it "shows the Changed Since Snapshot indicator" do
          get project_review_review_item_path(project, review, review_item)
          expect(response.body).to include("Changed Since Snapshot")
        end

        it "shows Changed badge on modified fields" do
          get project_review_review_item_path(project, review, review_item)
          expect(response.body).to include("Changed")
        end

        it "shows diff highlighting" do
          get project_review_review_item_path(project, review, review_item)
          expect(response.body).to include("rf-diff-del")
          expect(response.body).to include("rf-diff-add")
        end
      end

      it "shows the comments section" do
        get project_review_review_item_path(project, review, review_item)
        expect(response.body).to include("Comments")
      end

      it "shows comment form for participants who can comment" do
        get project_review_review_item_path(project, review, review_item)
        expect(response.body).to include("Add a comment")
      end

      it "shows empty comment state" do
        get project_review_review_item_path(project, review, review_item)
        expect(response.body).to include("No comments yet")
      end

      context "with comments" do
        let!(:comment) { create(:review_comment, review_item: review_item, user: reviewer_user, body: "Looks good to me") }

        it "shows the comment" do
          get project_review_review_item_path(project, review, review_item)
          expect(response.body).to include("Looks good to me")
          expect(response.body).to include(reviewer_user.full_name)
        end
      end

      it "shows Back to Review link" do
        get project_review_review_item_path(project, review, review_item)
        expect(response.body).to include("Back to Review")
      end

      it "scopes projects to current organization" do
        other_org = create(:organization)
        other_project = create(:project, organization: other_org)
        other_section = create(:section, requirement_module: create(:requirement_module, project: other_project))
        other_req = create(:requirement, project: other_project, section: other_section, created_by: admin_user)
        other_review = create(:review, project: other_project, created_by: admin_user)
        other_item = create(:review_item, review: other_review, requirement: other_req)

        get project_review_review_item_path(other_project, other_review, other_item)
        # Should not be able to access cross-org projects — either 404 or redirect
        expect(response).not_to have_http_status(:success)
      end
    end

    context "as a viewer" do
      before { sign_in viewer_user }

      it "allows viewing the review item" do
        get project_review_review_item_path(project, review, review_item)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "PATCH /projects/:project_id/reviews/:review_id/review_items/:id/update_status" do
    before { review.transition_to("in_progress") }

    context "as a reviewer participant" do
      before { sign_in reviewer_user }

      it "approves the item" do
        patch update_status_project_review_review_item_path(project, review, review_item, status: "approved")
        expect(review_item.reload.status).to eq("approved")
        expect(response).to redirect_to(project_review_review_item_path(project, review, review_item))
      end

      it "rejects the item" do
        patch update_status_project_review_review_item_path(project, review, review_item, status: "rejected")
        expect(review_item.reload.status).to eq("rejected")
      end

      it "marks as needs changes" do
        patch update_status_project_review_review_item_path(project, review, review_item, status: "needs_changes")
        expect(review_item.reload.status).to eq("needs_changes")
      end

      it "resets to pending" do
        review_item.update!(status: :approved)
        patch update_status_project_review_review_item_path(project, review, review_item, status: "pending")
        expect(review_item.reload.status).to eq("pending")
      end

      it "rejects invalid status" do
        patch update_status_project_review_review_item_path(project, review, review_item, status: "invalid")
        expect(response).to redirect_to(project_review_review_item_path(project, review, review_item))
        follow_redirect!
        expect(response.body).to include("Invalid status")
      end
    end

    context "when review is not in_progress" do
      before do
        review.update_column(:status, Review.statuses[:open])
        sign_in reviewer_user
      end

      it "denies status changes" do
        patch update_status_project_review_review_item_path(project, review, review_item, status: "approved")
        expect(response).to redirect_to(project_review_review_item_path(project, review, review_item))
        expect(review_item.reload.status).to eq("pending")
      end
    end

    context "as a viewer (non-participant)" do
      before { sign_in viewer_user }

      it "denies status changes" do
        patch update_status_project_review_review_item_path(project, review, review_item, status: "approved")
        expect(response).to redirect_to(project_review_review_item_path(project, review, review_item))
        expect(review_item.reload.status).to eq("pending")
      end
    end
  end
end
