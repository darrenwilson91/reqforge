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

      it "redirects to organization setup" do
        get root_path
        expect(response).to redirect_to(new_organization_path)
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

  describe "controller scoping helpers" do
    # Use a temporary table and test controller to exercise scoped_query and build_scoped
    before(:all) do
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Schema.define do
          create_table :tenant_test_items, force: true do |t|
            t.references :organization, null: false
            t.string :name
            t.timestamps
          end
        end
      end
    end

    after(:all) do
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Schema.define do
          drop_table :tenant_test_items, if_exists: true
        end
      end
    end

    # Define the model and controller inline for testing
    before do
      # Define model if not already defined
      unless Object.const_defined?(:TenantTestItem)
        Object.const_set(:TenantTestItem, Class.new(ApplicationRecord) {
          self.table_name = "tenant_test_items"
          include OrganizationScoped
        })
      end

      # Define controller if not already defined
      unless Object.const_defined?(:TenantTestItemsController)
        Object.const_set(:TenantTestItemsController, Class.new(ApplicationController) {
          skip_after_action :verify_authorized, raise: false
          skip_after_action :verify_policy_scoped, raise: false

          def index
            @items = scoped_query(TenantTestItem)
            render json: @items.map { |i| { id: i.id, name: i.name } }
          end

          def create
            @item = build_scoped(TenantTestItem, { name: params[:name] })
            if @item.save
              render json: { id: @item.id, name: @item.name, organization_id: @item.organization_id }, status: :created
            else
              render json: { errors: @item.errors.full_messages }, status: :unprocessable_entity
            end
          end
        })
      end

      # Draw temporary routes
      Rails.application.routes.draw do
        devise_for :users
        resources :organizations, only: [ :new, :create ]
        root "dashboard#index"
        resources :tenant_test_items, only: [ :index, :create ]
      end
    end

    after do
      # Restore original routes
      Rails.application.reload_routes!
    end

    let(:other_org) { create(:organization, name: "Other Org") }

    before do
      sign_in user
    end

    describe "scoped_query" do
      let!(:own_item) { TenantTestItem.create!(organization: organization, name: "Own Item") }
      let!(:other_item) { TenantTestItem.create!(organization: other_org, name: "Other Item") }

      it "returns only records belonging to the current organization" do
        get tenant_test_items_path
        expect(response).to have_http_status(:success)

        items = JSON.parse(response.body)
        item_names = items.map { |i| i["name"] }
        expect(item_names).to include("Own Item")
        expect(item_names).not_to include("Other Item")
      end

      it "returns different results after switching organization" do
        other_membership = create(:membership, user: user, organization: other_org)

        get tenant_test_items_path, params: { organization_id: other_org.id }
        items = JSON.parse(response.body)
        item_names = items.map { |i| i["name"] }
        expect(item_names).to include("Other Item")
        expect(item_names).not_to include("Own Item")
      end
    end

    describe "build_scoped" do
      it "creates a record scoped to the current organization" do
        post tenant_test_items_path, params: { name: "New Item" }
        expect(response).to have_http_status(:created)

        result = JSON.parse(response.body)
        expect(result["name"]).to eq("New Item")
        expect(result["organization_id"]).to eq(organization.id)
      end

      it "does not allow creating records for a different organization" do
        post tenant_test_items_path, params: { name: "New Item" }
        result = JSON.parse(response.body)

        item = TenantTestItem.find(result["id"])
        expect(item.organization).to eq(organization)
        expect(item.organization).not_to eq(other_org)
      end
    end
  end
end
