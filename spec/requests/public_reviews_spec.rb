require 'rails_helper'

RSpec.describe "PublicReviews", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization) }
  let(:req_module) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: req_module) }
  let(:requirement) { create(:requirement, project: project, section: section, created_by: user) }
  let(:review) { create(:review, project: project, created_by: user, status: :in_progress) }
  let!(:review_item) do
    item = create(:review_item, review: review, requirement: requirement)
    item.snapshot_requirement!
    item
  end
  let!(:participant) { create(:review_participant, review: review, user: user, role: :reviewer) }

  describe "GET /reviews/:token (public review show)" do
    context "with valid share token" do
      before { review.generate_share_token! }

      it "renders the public review page without authentication" do
        get public_review_path(review.share_token)
        expect(response).to have_http_status(:ok)
      end

      it "displays the review title" do
        get public_review_path(review.share_token)
        expect(response.body).to include(review.title)
      end

      it "displays the project name" do
        get public_review_path(review.share_token)
        expect(response.body).to include(project.name)
      end

      it "displays review status" do
        get public_review_path(review.share_token)
        expect(response.body).to include("In progress")
      end

      it "displays review items with requirement UIDs" do
        get public_review_path(review.share_token)
        expect(response.body).to include(requirement.uid)
      end

      it "displays the creator name" do
        get public_review_path(review.share_token)
        expect(response.body).to include(review.created_by.full_name)
      end

      it "displays participants" do
        get public_review_path(review.share_token)
        expect(response.body).to include(user.full_name)
      end

      it "displays stats cards" do
        get public_review_path(review.share_token)
        expect(response.body).to include("Total Items")
        expect(response.body).to include("Progress")
      end

      it "uses the public review layout" do
        get public_review_path(review.share_token)
        expect(response.body).to include("Read-only")
        expect(response.body).to include("Shared Review")
      end

      it "does not include editing actions" do
        get public_review_path(review.share_token)
        expect(response.body).not_to include("Edit")
        expect(response.body).not_to include("Delete")
        expect(response.body).not_to include("transition_status")
      end

      it "links review items to the public item detail page" do
        get public_review_path(review.share_token)
        expect(response.body).to include(public_review_item_path(review.share_token, item_id: review_item.id))
      end
    end

    context "with invalid token" do
      it "returns 404" do
        get public_review_path("nonexistent-token")
        expect(response).to have_http_status(:not_found)
      end

      it "shows a friendly error message" do
        get public_review_path("invalid-token-12345")
        expect(response.body).to include("Review not found")
      end
    end

    context "when review has no share token" do
      it "returns 404 when accessing via nil token" do
        get "/reviews/"
        expect(response).to have_http_status(:not_found).or have_http_status(:moved_permanently).or have_http_status(:redirect)
      end
    end
  end

  describe "GET /reviews/:token/items/:item_id (public review item)" do
    before { review.generate_share_token! }

    context "with valid token and item" do
      it "renders the review item detail page" do
        get public_review_item_path(review.share_token, item_id: review_item.id)
        expect(response).to have_http_status(:ok)
      end

      it "displays the requirement UID" do
        get public_review_item_path(review.share_token, item_id: review_item.id)
        expect(response.body).to include(requirement.uid)
      end

      it "displays the requirement title" do
        get public_review_item_path(review.share_token, item_id: review_item.id)
        expect(response.body).to include(requirement.title)
      end

      it "displays the diff fields section" do
        get public_review_item_path(review.share_token, item_id: review_item.id)
        expect(response.body).to include("Requirement Changes")
      end

      it "displays the comments section" do
        get public_review_item_path(review.share_token, item_id: review_item.id)
        expect(response.body).to include("Comments")
      end

      it "shows a back link to the public review" do
        get public_review_item_path(review.share_token, item_id: review_item.id)
        expect(response.body).to include(public_review_path(review.share_token))
        expect(response.body).to include("Back to Review")
      end

      it "does not include decision buttons" do
        get public_review_item_path(review.share_token, item_id: review_item.id)
        expect(response.body).not_to include("Approve")
        expect(response.body).not_to include("Reject")
        expect(response.body).not_to include("Needs Changes")
      end

      it "does not include comment form" do
        get public_review_item_path(review.share_token, item_id: review_item.id)
        expect(response.body).not_to include("Add a comment")
      end

      it "uses the public review layout" do
        get public_review_item_path(review.share_token, item_id: review_item.id)
        expect(response.body).to include("Read-only")
      end
    end

    context "with comments on the item" do
      let!(:comment) { create(:review_comment, review_item: review_item, user: user, body: "This looks good to me") }

      it "displays existing comments read-only" do
        get public_review_item_path(review.share_token, item_id: review_item.id)
        expect(response.body).to include("This looks good to me")
        expect(response.body).to include(user.full_name)
      end
    end

    context "with invalid item ID" do
      it "returns 404 for non-existent item" do
        get public_review_item_path(review.share_token, item_id: 999999)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with invalid token" do
      it "returns 404" do
        get public_review_item_path("bad-token", item_id: review_item.id)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
