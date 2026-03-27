require "rails_helper"

RSpec.describe "Multi-tenancy", type: :request do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let!(:membership) { create(:membership, user: user, organization: organization) }

  describe "organization resolution" do
    context "when user is not signed in" do
      it "redirects to sign in page" do
        get root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is signed in" do
      before { sign_in user }

      it "sets current organization from user's memberships" do
        get root_path
        expect(response).to have_http_status(:success)
      end

      it "stores organization in session" do
        get root_path
        expect(session[:current_organization_id]).to eq(organization.id)
      end

      it "switches organization via organization_id param" do
        other_org = create(:organization)
        create(:membership, user: user, organization: other_org)

        get root_path, params: { organization_id: other_org.id }
        expect(session[:current_organization_id]).to eq(other_org.id)
      end

      it "ignores organization_id param if user is not a member" do
        other_org = create(:organization)

        get root_path, params: { organization_id: other_org.id }
        expect(session[:current_organization_id]).to eq(organization.id)
      end

      it "falls back to first organization when session org is invalid" do
        get root_path
        # Simulate stale session by removing the membership
        membership.destroy!
        new_org = create(:organization)
        create(:membership, user: user, organization: new_org)

        get root_path
        expect(session[:current_organization_id]).to eq(new_org.id)
      end
    end

    context "when user has no organizations" do
      let(:user_without_org) { create(:user) }

      before { sign_in user_without_org }

      it "still allows access to dashboard" do
        get root_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "current_membership" do
    before { sign_in user }

    it "finds the membership for the current user and organization" do
      get root_path
      # Verify indirectly — the request succeeds and session is set
      expect(session[:current_organization_id]).to eq(organization.id)
    end
  end
end
