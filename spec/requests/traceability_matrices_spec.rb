require "rails_helper"

RSpec.describe "TraceabilityMatrices", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization) }
  let(:req_module) { create(:requirement_module, project: project, name: "System Requirements") }
  let(:section) { create(:section, requirement_module: req_module) }

  before { sign_in user }

  def create_req(**attrs)
    create(:requirement, project: project, section: section, created_by: user, **attrs)
  end

  describe "GET /projects/:project_id/traceability_matrix" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        get project_traceability_matrix_path(project)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it "renders the matrix page" do
      get project_traceability_matrix_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Traceability Matrix")
    end

    it "shows breadcrumbs with project name" do
      get project_traceability_matrix_path(project)
      expect(response.body).to include("Projects")
      expect(response.body).to include(project.name)
      expect(response.body).to include("Traceability Matrix")
    end

    it "shows coverage summary cards" do
      get project_traceability_matrix_path(project)
      expect(response.body).to include("Total")
      expect(response.body).to include("Linked")
      expect(response.body).to include("Unlinked")
      expect(response.body).to include("Coverage")
    end

    context "with no links" do
      before { create_req(title: "Unlinked Req") }

      it "shows empty state" do
        get project_traceability_matrix_path(project)
        expect(response.body).to include("No traceability links yet")
        expect(response.body).to include("Go to Requirements")
      end

      it "shows unlinked requirements table" do
        get project_traceability_matrix_path(project)
        expect(response.body).to include("Unlinked Requirements")
        expect(response.body).to include("Unlinked Req")
      end
    end

    context "with links" do
      let!(:source) { create_req(title: "Source Req") }
      let!(:target) { create_req(title: "Target Req") }
      let!(:link) do
        create(:traceability_link,
          source_requirement: source,
          target_requirement: target,
          link_type: :derives_from,
          created_by: user
        )
      end

      it "renders the matrix grid" do
        get project_traceability_matrix_path(project)
        expect(response.body).to include(source.uid)
        expect(response.body).to include(target.uid)
      end

      it "shows requirement count in header" do
        get project_traceability_matrix_path(project)
        expect(response.body).to include("2 requirements")
      end

      it "shows coverage metrics" do
        get project_traceability_matrix_path(project)
        # Both requirements are linked, so coverage should be 100
        expect(response.body).to include("Coverage")
        expect(response.body).to include("Forward")
        expect(response.body).to include("Backward")
      end

      it "shows the legend" do
        get project_traceability_matrix_path(project)
        expect(response.body).to include("Legend:")
        expect(response.body).to include("Derives from")
      end

      it "shows Graph View navigation button" do
        get project_traceability_matrix_path(project)
        expect(response.body).to include("Graph View")
      end

      it "shows Requirements navigation button" do
        get project_traceability_matrix_path(project)
        expect(response.body).to include("Requirements")
      end

      it "shows per-link-type coverage table" do
        get project_traceability_matrix_path(project)
        expect(response.body).to include("Coverage by Link Type")
        expect(response.body).to include("Forward (Outgoing)")
        expect(response.body).to include("Backward (Incoming)")
      end
    end

    it "shows test coverage section" do
      get project_traceability_matrix_path(project)
      expect(response.body).to include("Test Coverage")
    end

    context "with no test cases" do
      before { create_req(title: "Some Req") }

      it "shows empty test coverage state" do
        get project_traceability_matrix_path(project)
        expect(response.body).to include("No test cases linked to requirements yet")
      end
    end

    context "with test cases" do
      let!(:req1) { create_req(title: "Tested Req") }
      let!(:req2) { create_req(title: "Untested Req") }

      before do
        create(:test_case, project: project, requirement: req1, status: :passed, created_by: user)
        create(:test_case, project: project, requirement: req1, status: :failed, created_by: user)
        create(:test_case, project: project, requirement: req2, status: :not_run, created_by: user)
      end

      it "shows test case count" do
        get project_traceability_matrix_path(project)
        expect(response.body).to include("3 test cases")
      end

      it "shows coverage percentage" do
        get project_traceability_matrix_path(project)
        expect(response.body).to include("100.0%")
        expect(response.body).to include("Requirements with test cases")
      end

      it "shows status breakdown" do
        get project_traceability_matrix_path(project)
        expect(response.body).to include("Passed")
        expect(response.body).to include("Failed")
        expect(response.body).to include("Not Run")
      end

      it "shows per-status requirement coverage" do
        get project_traceability_matrix_path(project)
        expect(response.body).to include("Req with passed tests")
        expect(response.body).to include("Req with failed tests")
        expect(response.body).to include("Req with untested cases")
      end
    end

    context "with filters" do
      let(:mod_a) { create(:requirement_module, project: project, name: "Module A") }
      let(:mod_b) { create(:requirement_module, project: project, name: "Module B") }
      let(:sec_a) { create(:section, requirement_module: mod_a) }
      let(:sec_b) { create(:section, requirement_module: mod_b) }
      let!(:req_a) { create(:requirement, project: project, section: sec_a, created_by: user, title: "Req A") }
      let!(:req_b) { create(:requirement, project: project, section: sec_b, created_by: user, title: "Req B") }
      let!(:link) do
        create(:traceability_link,
          source_requirement: req_a,
          target_requirement: req_b,
          link_type: :satisfies,
          created_by: user
        )
      end

      it "filters by source module" do
        get project_traceability_matrix_path(project), params: { source_module: mod_a.id }
        expect(response).to have_http_status(:success)
        expect(response.body).to include(req_a.uid)
      end

      it "filters by target module" do
        get project_traceability_matrix_path(project), params: { target_module: mod_b.id }
        expect(response).to have_http_status(:success)
        expect(response.body).to include(req_b.uid)
      end

      it "filters by link type" do
        get project_traceability_matrix_path(project), params: { link_types: ["satisfies"] }
        expect(response).to have_http_status(:success)
      end

      it "shows Clear button when filters are active" do
        get project_traceability_matrix_path(project), params: { source_module: mod_a.id }
        expect(response.body).to include("Clear")
      end

      it "does not show Clear button without filters" do
        get project_traceability_matrix_path(project)
        expect(response.body).not_to include("Clear")
      end
    end

    context "multi-tenancy" do
      it "returns 404 for projects in other organizations" do
        other_org = create(:organization)
        other_project = create(:project, organization: other_org)

        get project_traceability_matrix_path(other_project)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "role-based access" do
      it "allows viewers to see the matrix" do
        viewer = create(:user)
        create(:membership, user: viewer, organization: organization, role: :viewer)
        sign_in viewer

        get project_traceability_matrix_path(project)
        expect(response).to have_http_status(:success)
      end

      it "allows reviewers to see the matrix" do
        reviewer = create(:user)
        create(:membership, user: reviewer, organization: organization, role: :reviewer)
        sign_in reviewer

        get project_traceability_matrix_path(project)
        expect(response).to have_http_status(:success)
      end
    end
  end
end
