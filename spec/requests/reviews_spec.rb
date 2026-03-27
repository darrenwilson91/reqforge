require "rails_helper"

RSpec.describe "Reviews", type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user) }
  let(:pm_user) { create(:user) }
  let(:author_user) { create(:user) }
  let(:reviewer_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:project) { create(:project, organization: organization) }

  before do
    create(:membership, user: admin_user, organization: organization, role: :admin)
    create(:membership, user: pm_user, organization: organization, role: :project_manager)
    create(:membership, user: author_user, organization: organization, role: :author)
    create(:membership, user: reviewer_user, organization: organization, role: :reviewer)
    create(:membership, user: viewer_user, organization: organization, role: :viewer)
  end

  # Helper to create requirements for testing
  def create_requirements(project, count = 3)
    mod = create(:requirement_module, project: project)
    section = create(:section, requirement_module: mod)
    count.times.map do
      create(:requirement, project: project, section: section, created_by: admin_user)
    end
  end

  describe "GET /projects/:project_id/reviews" do
    it "redirects unauthenticated users" do
      get project_reviews_path(project)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the index page" do
      sign_in admin_user
      review = create(:review, project: project, created_by: admin_user)
      get project_reviews_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(review.title)
    end

    it "shows empty state when no reviews exist" do
      sign_in admin_user
      get project_reviews_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("No reviews yet")
    end

    it "shows reviews with progress" do
      sign_in admin_user
      review = create(:review, project: project, created_by: admin_user)
      reqs = create_requirements(project, 2)
      create(:review_item, review: review, requirement: reqs[0], status: :approved)
      create(:review_item, review: review, requirement: reqs[1], status: :pending)
      get project_reviews_path(project)
      expect(response.body).to include("50%")
      expect(response.body).to include("1/2 decided")
    end

    it "returns 404 for cross-organization project" do
      sign_in admin_user
      other_org = create(:organization)
      other_project = create(:project, organization: other_org)
      get project_reviews_path(other_project)
      expect(response).to have_http_status(:not_found)
    end

    it "allows viewer access" do
      sign_in viewer_user
      get project_reviews_path(project)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /projects/:project_id/reviews/new" do
    it "renders the new review form" do
      sign_in admin_user
      get new_project_review_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Create Review")
    end

    it "shows available requirements" do
      sign_in admin_user
      reqs = create_requirements(project, 2)
      get new_project_review_path(project)
      reqs.each do |req|
        expect(response.body).to include(req.uid)
      end
    end

    it "shows organization members for participants" do
      sign_in admin_user
      get new_project_review_path(project)
      # Other members should be shown (not current user)
      expect(response.body).to include(pm_user.full_name)
      expect(response.body).to include(author_user.full_name)
    end

    it "denies viewer access" do
      sign_in viewer_user
      get new_project_review_path(project)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /projects/:project_id/reviews" do
    let(:requirements) { create_requirements(project, 3) }

    it "creates a review with selected requirements" do
      sign_in admin_user
      expect {
        post project_reviews_path(project), params: {
          review: {
            title: "Sprint Review",
            description: "Review of sprint deliverables",
            requirement_ids: requirements.map(&:id)
          }
        }
      }.to change(Review, :count).by(1)
        .and change(ReviewItem, :count).by(3)

      review = Review.last
      expect(review.title).to eq("Sprint Review")
      expect(review.created_by).to eq(admin_user)
      expect(review.review_items.count).to eq(3)
      expect(response).to redirect_to(project_review_path(project, review))
    end

    it "snapshots requirements when creating review items" do
      sign_in admin_user
      post project_reviews_path(project), params: {
        review: {
          title: "Snapshot Test",
          requirement_ids: [requirements.first.id]
        }
      }
      review = Review.last
      item = review.review_items.first
      expect(item.snapshot).to include("title" => requirements.first.title)
    end

    it "creates baseline snapshot of the project" do
      sign_in admin_user
      post project_reviews_path(project), params: {
        review: {
          title: "Baseline Test",
          requirement_ids: [requirements.first.id]
        }
      }
      review = Review.last
      expect(review.baseline_snapshot).to be_an(Array)
      expect(review.baseline_snapshot.size).to eq(3)
    end

    it "adds the creator as author participant" do
      sign_in admin_user
      post project_reviews_path(project), params: {
        review: {
          title: "Participant Test",
          requirement_ids: [requirements.first.id]
        }
      }
      review = Review.last
      author_participant = review.review_participants.find_by(user: admin_user)
      expect(author_participant).to be_present
      expect(author_participant.role).to eq("author")
    end

    it "adds selected reviewers and approvers" do
      sign_in admin_user
      post project_reviews_path(project), params: {
        review: {
          title: "Team Review",
          requirement_ids: [requirements.first.id],
          reviewer_ids: [reviewer_user.id],
          approver_ids: [pm_user.id]
        }
      }
      review = Review.last
      expect(review.review_participants.count).to eq(3) # author + reviewer + approver
      expect(review.review_participants.find_by(user: reviewer_user).role).to eq("reviewer")
      expect(review.review_participants.find_by(user: pm_user).role).to eq("approver")
    end

    it "rejects blank title" do
      sign_in admin_user
      post project_reviews_path(project), params: {
        review: { title: "", requirement_ids: [requirements.first.id] }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "allows author role to create" do
      sign_in author_user
      post project_reviews_path(project), params: {
        review: {
          title: "Author Review",
          requirement_ids: [requirements.first.id]
        }
      }
      expect(Review.last.title).to eq("Author Review")
    end

    it "denies viewer access" do
      sign_in viewer_user
      post project_reviews_path(project), params: {
        review: { title: "Viewer Review", requirement_ids: [requirements.first.id] }
      }
      expect(response).to redirect_to(root_path)
    end

    it "denies reviewer role access to create" do
      sign_in reviewer_user
      post project_reviews_path(project), params: {
        review: { title: "Reviewer Review", requirement_ids: [requirements.first.id] }
      }
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /projects/:project_id/reviews/:id" do
    let(:review) { create(:review, project: project, created_by: admin_user) }

    it "renders the review detail page" do
      sign_in admin_user
      get project_review_path(project, review)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(review.title)
    end

    it "shows review items" do
      sign_in admin_user
      reqs = create_requirements(project, 2)
      create(:review_item, review: review, requirement: reqs[0])
      create(:review_item, review: review, requirement: reqs[1])
      get project_review_path(project, review)
      expect(response.body).to include(reqs[0].uid)
      expect(response.body).to include(reqs[1].uid)
    end

    it "shows participants" do
      sign_in admin_user
      create(:review_participant, review: review, user: admin_user, role: :author)
      create(:review_participant, review: review, user: reviewer_user, role: :reviewer)
      get project_review_path(project, review)
      expect(response.body).to include(admin_user.full_name)
      expect(response.body).to include(reviewer_user.full_name)
      expect(response.body).to include("Author")
      expect(response.body).to include("Reviewer")
    end

    it "shows progress stats" do
      sign_in admin_user
      reqs = create_requirements(project, 2)
      create(:review_item, :approved, review: review, requirement: reqs[0])
      create(:review_item, review: review, requirement: reqs[1])
      get project_review_path(project, review)
      expect(response.body).to include("50%")
      expect(response.body).to include("Total Items")
      expect(response.body).to include("Approved")
    end

    it "shows status transition buttons for authorized users" do
      sign_in admin_user
      get project_review_path(project, review)
      expect(response.body).to include("Open for Review")
    end

    it "shows breadcrumbs" do
      sign_in admin_user
      get project_review_path(project, review)
      expect(response.body).to include("Reviews")
      expect(response.body).to include(project.name)
    end

    it "shows changed indicator on review items" do
      sign_in admin_user
      reqs = create_requirements(project)
      item = create(:review_item, :with_snapshot, review: review, requirement: reqs[0])
      # Change requirement after snapshot
      reqs[0].update!(title: "Changed Title After Snapshot")
      get project_review_path(project, review)
      expect(response.body).to include("Changed")
    end

    it "allows viewer access" do
      sign_in viewer_user
      get project_review_path(project, review)
      expect(response).to have_http_status(:success)
    end

    it "returns 404 for cross-org project" do
      sign_in admin_user
      other_org = create(:organization)
      other_project = create(:project, organization: other_org)
      other_review = create(:review, project: other_project, created_by: admin_user)
      get project_review_path(other_project, other_review)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /projects/:project_id/reviews/:id/edit" do
    let(:review) { create(:review, project: project, created_by: admin_user) }

    it "renders the edit form for draft review" do
      sign_in admin_user
      get edit_project_review_path(project, review)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Edit Review")
      expect(response.body).to include(review.title)
    end

    it "allows the creator to edit" do
      sign_in admin_user
      get edit_project_review_path(project, review)
      expect(response).to have_http_status(:success)
    end

    it "allows PM to edit" do
      sign_in pm_user
      get edit_project_review_path(project, review)
      expect(response).to have_http_status(:success)
    end

    it "denies viewer access" do
      sign_in viewer_user
      get edit_project_review_path(project, review)
      expect(response).to redirect_to(root_path)
    end

    it "denies reviewer who is not the creator" do
      sign_in reviewer_user
      get edit_project_review_path(project, review)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /projects/:project_id/reviews/:id" do
    let(:review) { create(:review, project: project, created_by: admin_user) }

    it "updates the review title" do
      sign_in admin_user
      patch project_review_path(project, review), params: {
        review: { title: "Updated Title" }
      }
      expect(review.reload.title).to eq("Updated Title")
      expect(response).to redirect_to(project_review_path(project, review))
    end

    it "updates the description" do
      sign_in admin_user
      patch project_review_path(project, review), params: {
        review: { description: "Updated description" }
      }
      expect(review.reload.description).to eq("Updated description")
    end

    it "rejects blank title" do
      sign_in admin_user
      patch project_review_path(project, review), params: {
        review: { title: "" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "denies viewer access" do
      sign_in viewer_user
      patch project_review_path(project, review), params: {
        review: { title: "Hacked" }
      }
      expect(response).to redirect_to(root_path)
      expect(review.reload.title).not_to eq("Hacked")
    end
  end

  describe "DELETE /projects/:project_id/reviews/:id" do
    let!(:review) { create(:review, project: project, created_by: admin_user) }

    it "deletes the review" do
      sign_in admin_user
      expect {
        delete project_review_path(project, review)
      }.to change(Review, :count).by(-1)
      expect(response).to redirect_to(project_reviews_path(project))
    end

    it "allows PM to delete" do
      sign_in pm_user
      expect {
        delete project_review_path(project, review)
      }.to change(Review, :count).by(-1)
    end

    it "denies author access to delete" do
      sign_in author_user
      delete project_review_path(project, review)
      expect(response).to redirect_to(root_path)
      expect(Review.exists?(review.id)).to be true
    end

    it "denies viewer access to delete" do
      sign_in viewer_user
      delete project_review_path(project, review)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /projects/:project_id/reviews/:id/transition_status" do
    let(:review) { create(:review, project: project, created_by: admin_user) }

    it "transitions draft to open" do
      sign_in admin_user
      patch transition_status_project_review_path(project, review), params: { status: "open" }
      expect(review.reload.status).to eq("open")
      expect(response).to redirect_to(project_review_path(project, review))
    end

    it "transitions open to in_progress" do
      sign_in admin_user
      review.update_column(:status, 1) # open
      patch transition_status_project_review_path(project, review), params: { status: "in_progress" }
      expect(review.reload.status).to eq("in_progress")
    end

    it "transitions in_progress to completed" do
      sign_in admin_user
      review.update_column(:status, 2) # in_progress
      patch transition_status_project_review_path(project, review), params: { status: "completed" }
      expect(review.reload.status).to eq("completed")
    end

    it "allows cancellation from any non-completed status" do
      sign_in admin_user
      review.update_column(:status, 1) # open
      patch transition_status_project_review_path(project, review), params: { status: "cancelled" }
      expect(review.reload.status).to eq("cancelled")
    end

    it "allows reopen cancelled to draft" do
      sign_in admin_user
      review.update_column(:status, 4) # cancelled
      patch transition_status_project_review_path(project, review), params: { status: "draft" }
      expect(review.reload.status).to eq("draft")
    end

    it "rejects invalid transition" do
      sign_in admin_user
      patch transition_status_project_review_path(project, review), params: { status: "completed" }
      expect(review.reload.status).to eq("draft")
      expect(flash[:alert]).to be_present
    end

    it "tracks transition in paper_trail" do
      sign_in admin_user
      expect {
        patch transition_status_project_review_path(project, review), params: { status: "open" }
      }.to change { review.versions.count }.by(1)
    end

    it "allows the creator to transition" do
      creator = create(:user)
      create(:membership, user: creator, organization: organization, role: :author)
      review_by_author = create(:review, project: project, created_by: creator)
      sign_in creator
      patch transition_status_project_review_path(project, review_by_author), params: { status: "open" }
      expect(review_by_author.reload.status).to eq("open")
    end

    it "denies viewer access" do
      sign_in viewer_user
      patch transition_status_project_review_path(project, review), params: { status: "open" }
      expect(response).to redirect_to(root_path)
      expect(review.reload.status).to eq("draft")
    end

    it "denies reviewer who is not the creator" do
      sign_in reviewer_user
      patch transition_status_project_review_path(project, review), params: { status: "open" }
      expect(response).to redirect_to(root_path)
    end

    it "completes full workflow: draft -> open -> in_progress -> completed" do
      sign_in admin_user
      patch transition_status_project_review_path(project, review), params: { status: "open" }
      expect(review.reload.status).to eq("open")

      patch transition_status_project_review_path(project, review), params: { status: "in_progress" }
      expect(review.reload.status).to eq("in_progress")

      patch transition_status_project_review_path(project, review), params: { status: "completed" }
      expect(review.reload.status).to eq("completed")
    end
  end
end
