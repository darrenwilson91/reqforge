require "rails_helper"

RSpec.describe "TraceabilityGraphs", type: :request do
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

  describe "GET /projects/:project_id/traceability_graph" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        get project_traceability_graph_path(project)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it "renders the graph page" do
      get project_traceability_graph_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Traceability Graph")
    end

    it "shows breadcrumbs with project name" do
      get project_traceability_graph_path(project)
      expect(response.body).to include("Projects")
      expect(response.body).to include(project.name)
      expect(response.body).to include("Traceability Graph")
    end

    context "with no links" do
      it "shows empty state" do
        get project_traceability_graph_path(project)
        expect(response.body).to include("No traceability links yet")
        expect(response.body).to include("Go to Requirements")
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

      it "renders the SVG canvas" do
        get project_traceability_graph_path(project)
        expect(response.body).to include("data-controller=\"graph\"")
        expect(response.body).to include("data-graph-nodes-value")
        expect(response.body).to include("data-graph-edges-value")
      end

      it "includes graph data for nodes" do
        get project_traceability_graph_path(project)
        expect(response.body).to include(source.uid)
        expect(response.body).to include(target.uid)
      end

      it "shows requirement and link counts in header" do
        get project_traceability_graph_path(project)
        expect(response.body).to include("2 requirements")
        expect(response.body).to include("1 link")
      end

      it "shows the link type legend" do
        get project_traceability_graph_path(project)
        expect(response.body).to include("Link Types")
        expect(response.body).to include("Derives from")
      end

      it "shows the module legend" do
        get project_traceability_graph_path(project)
        expect(response.body).to include("Modules")
        expect(response.body).to include(req_module.name)
      end

      it "shows coverage summary cards" do
        get project_traceability_graph_path(project)
        expect(response.body).to include("Total Requirements")
        expect(response.body).to include("Linked")
        expect(response.body).to include("Coverage")
      end

      it "shows Matrix View navigation button" do
        get project_traceability_graph_path(project)
        expect(response.body).to include("Matrix View")
      end

      it "shows zoom controls" do
        get project_traceability_graph_path(project)
        expect(response.body).to include("Zoom in")
        expect(response.body).to include("Zoom out")
        expect(response.body).to include("Fit to view")
      end

      it "shows interaction hints" do
        get project_traceability_graph_path(project)
        expect(response.body).to include("Scroll to zoom")
        expect(response.body).to include("Drag nodes to rearrange")
      end
    end

    context "multi-tenancy" do
      it "returns 404 for projects in other organizations" do
        other_org = create(:organization)
        other_project = create(:project, organization: other_org)

        get project_traceability_graph_path(other_project)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "role-based access" do
      it "allows viewers to see the graph" do
        viewer = create(:user)
        create(:membership, user: viewer, organization: organization, role: :viewer)
        sign_in viewer

        get project_traceability_graph_path(project)
        expect(response).to have_http_status(:success)
      end
    end
  end
end
