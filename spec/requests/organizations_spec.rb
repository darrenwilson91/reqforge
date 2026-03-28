require "rails_helper"

RSpec.describe "Organizations", type: :request do
  describe "GET /organizations/new" do
    context "when not signed in" do
      it "redirects to sign in" do
        get new_organization_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in without an organization" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "renders the new organization form" do
        get new_organization_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Create Your Organization")
      end
    end

    context "when signed in with an organization" do
      let(:user) { create(:user) }
      let(:organization) { create(:organization) }

      before do
        create(:membership, user: user, organization: organization)
        sign_in user
      end

      it "still allows access to the new organization form" do
        get new_organization_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "POST /organizations" do
    context "when not signed in" do
      it "redirects to sign in" do
        post organizations_path, params: { organization: { name: "Test Org" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "creates an organization with valid params" do
        expect {
          post organizations_path, params: { organization: { name: "Acme Engineering" } }
        }.to change(Organization, :count).by(1)

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("Organization created successfully")
      end

      it "creates the user as an admin member of the organization" do
        post organizations_path, params: { organization: { name: "Acme Engineering" } }

        org = Organization.last
        membership = Membership.find_by(user: user, organization: org)
        expect(membership).to be_present
        expect(membership.role).to eq("admin")
      end

      it "sets the new organization as the current organization in session" do
        post organizations_path, params: { organization: { name: "Acme Engineering" } }

        org = Organization.last
        expect(session[:current_organization_id]).to eq(org.id)
      end

      it "auto-generates a slug from the organization name" do
        post organizations_path, params: { organization: { name: "Acme Engineering" } }

        org = Organization.last
        expect(org.slug).to eq("acme-engineering")
      end

      it "re-renders the form with errors for invalid params" do
        post organizations_path, params: { organization: { name: "" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Please fix the following")
      end

      it "does not create an organization with a blank name" do
        expect {
          post organizations_path, params: { organization: { name: "" } }
        }.not_to change(Organization, :count)
      end
    end
  end

  describe "organization setup redirect flow" do
    let(:user) { create(:user) }

    before { sign_in user }

    it "redirects to organization setup when visiting dashboard without an organization" do
      get root_path
      expect(response).to redirect_to(new_organization_path)
    end

    it "allows access to dashboard after creating an organization" do
      post organizations_path, params: { organization: { name: "My Team" } }
      expect(response).to redirect_to(root_path)

      follow_redirect!
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Welcome back")
    end

    it "completes the full sign-up to dashboard flow" do
      # Step 1: User without org gets redirected
      get root_path
      expect(response).to redirect_to(new_organization_path)

      # Step 2: User visits org setup page
      follow_redirect!
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Create Your Organization")

      # Step 3: User creates an organization
      post organizations_path, params: { organization: { name: "New Corp" } }
      expect(response).to redirect_to(root_path)

      # Step 4: User lands on dashboard with their organization
      follow_redirect!
      expect(response).to have_http_status(:success)
      expect(response.body).to include("New Corp")
    end
  end
end
