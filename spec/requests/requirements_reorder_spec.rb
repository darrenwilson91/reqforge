require "rails_helper"

RSpec.describe "Requirements reorder", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:project) { create(:project, organization: organization) }
  let(:mod) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: mod) }

  before { sign_in user }

  let!(:req1) { create(:requirement, project: project, section: section, title: "First", position: 1) }
  let!(:req2) { create(:requirement, project: project, section: section, title: "Second", position: 2) }
  let!(:req3) { create(:requirement, project: project, section: section, title: "Third", position: 3) }

  describe "PATCH /projects/:project_id/requirements/reorder" do
    context "when user is admin" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }

      it "reorders requirements according to the provided order" do
        patch reorder_project_requirements_path(project),
              params: { ordered_ids: [ req3.id, req1.id, req2.id ] },
              as: :json

        expect(response).to have_http_status(:ok)
        expect(req3.reload.position).to eq(1)
        expect(req1.reload.position).to eq(2)
        expect(req2.reload.position).to eq(3)
      end

      it "handles reordering to the same position" do
        patch reorder_project_requirements_path(project),
              params: { ordered_ids: [ req1.id, req2.id, req3.id ] },
              as: :json

        expect(response).to have_http_status(:ok)
        expect(req1.reload.position).to eq(1)
        expect(req2.reload.position).to eq(2)
        expect(req3.reload.position).to eq(3)
      end

      it "handles a partial reorder (subset of requirements)" do
        patch reorder_project_requirements_path(project),
              params: { ordered_ids: [ req2.id, req1.id ] },
              as: :json

        expect(response).to have_http_status(:ok)
        expect(req2.reload.position).to eq(1)
        expect(req1.reload.position).to eq(2)
        # req3 not included — position unchanged
        expect(req3.reload.position).to eq(3)
      end

      it "ignores IDs from other projects" do
        other_project = create(:project, organization: organization)
        other_mod = create(:requirement_module, project: other_project)
        other_section = create(:section, requirement_module: other_mod)
        other_req = create(:requirement, project: other_project, section: other_section, position: 1)

        patch reorder_project_requirements_path(project),
              params: { ordered_ids: [ other_req.id, req1.id ] },
              as: :json

        expect(response).to have_http_status(:ok)
        # other_req should not be modified — it belongs to a different project
        expect(other_req.reload.position).to eq(1)
        expect(req1.reload.position).to eq(2)
      end

      it "rejects non-numeric IDs" do
        patch reorder_project_requirements_path(project),
              params: { ordered_ids: [ "abc", "def" ] },
              as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects non-array params" do
        patch reorder_project_requirements_path(project),
              params: { ordered_ids: "not-an-array" },
              as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when user is project_manager" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :project_manager) }

      it "allows reordering" do
        patch reorder_project_requirements_path(project),
              params: { ordered_ids: [ req2.id, req1.id, req3.id ] },
              as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context "when user is author" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :author) }

      it "denies reordering" do
        patch reorder_project_requirements_path(project),
              params: { ordered_ids: [ req2.id, req1.id, req3.id ] },
              as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "denies reordering" do
        patch reorder_project_requirements_path(project),
              params: { ordered_ids: [ req2.id, req1.id, req3.id ] },
              as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        patch reorder_project_requirements_path(project),
              params: { ordered_ids: [ req1.id ] },
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
