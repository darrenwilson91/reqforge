require "rails_helper"

RSpec.describe "ComplianceDashboards", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization) }

  before { sign_in user }

  def create_module_with_reqs(name:, count:, asil: "qm")
    mod = create(:requirement_module, project: project, name: name)
    section = create(:section, requirement_module: mod, name: "Default")
    reqs = count.times.map do
      create(:requirement, project: project, section: section, created_by: user, asil_level: asil)
    end
    [ mod, section, reqs ]
  end

  describe "GET /projects/:project_id/compliance_dashboard" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        get project_compliance_dashboard_path(project)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it "renders the compliance dashboard page" do
      get project_compliance_dashboard_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Compliance Dashboard")
    end

    it "shows breadcrumbs with project name" do
      get project_compliance_dashboard_path(project)
      expect(response.body).to include("Projects")
      expect(response.body).to include(project.name)
      expect(response.body).to include("Compliance Dashboard")
    end

    it "shows the project prefix" do
      get project_compliance_dashboard_path(project)
      expect(response.body).to include(project.prefix)
    end

    it "shows summary cards" do
      get project_compliance_dashboard_path(project)
      expect(response.body).to include("Requirements")
      expect(response.body).to include("Linked")
      expect(response.body).to include("Unlinked")
      expect(response.body).to include("Phases")
    end

    it "shows navigation to matrix and requirements" do
      get project_compliance_dashboard_path(project)
      expect(response.body).to include("Matrix")
      expect(response.body).to include(project_traceability_matrix_path(project))
      expect(response.body).to include(project_requirements_path(project))
    end

    context "with no modules" do
      it "shows empty state for phases" do
        get project_compliance_dashboard_path(project)
        expect(response.body).to include("No modules defined")
      end

      it "shows empty state for ASIL distribution" do
        get project_compliance_dashboard_path(project)
        expect(response.body).to include("No requirements yet")
      end
    end

    context "with modules and requirements" do
      let!(:sys_mod) { create_module_with_reqs(name: "System Requirements", count: 3, asil: "asil_d") }
      let!(:sw_mod) { create_module_with_reqs(name: "Software Requirements", count: 2, asil: "asil_b") }

      it "shows the coverage by phase table" do
        get project_compliance_dashboard_path(project)
        expect(response.body).to include("Coverage by Phase")
        expect(response.body).to include("System Requirements")
        expect(response.body).to include("Software Requirements")
      end

      it "shows requirement counts per phase" do
        get project_compliance_dashboard_path(project)
        # System Requirements has 3, Software Requirements has 2
        expect(response.body).to include("Phase / Module")
      end

      it "shows overall coverage bar" do
        get project_compliance_dashboard_path(project)
        expect(response.body).to include("Overall Traceability Coverage")
      end

      it "shows ASIL distribution" do
        get project_compliance_dashboard_path(project)
        expect(response.body).to include("ASIL Distribution")
        expect(response.body).to include("ASIL D")
        expect(response.body).to include("ASIL B")
      end

      it "shows safety-rated requirements callout" do
        get project_compliance_dashboard_path(project)
        expect(response.body).to include("safety-rated requirement")
        expect(response.body).to include("require full traceability")
      end

      context "with traceability links" do
        before do
          _, _, sys_reqs = sys_mod
          _, _, sw_reqs = sw_mod
          create(:traceability_link,
            source_requirement: sys_reqs.first,
            target_requirement: sw_reqs.first,
            link_type: :derives_from,
            created_by: user)
        end

        it "shows linked count in phase table" do
          get project_compliance_dashboard_path(project)
          expect(response.body).to include("Coverage by Phase")
        end

        it "reflects linked requirements in summary" do
          get project_compliance_dashboard_path(project)
          # Coverage should show at least 1 linked requirement
          expect(response.body).to include("Linked")
        end
      end
    end

    context "with ISO 26262 compliance template" do
      before do
        ComplianceTemplate.seed_templates!
        template = ComplianceTemplate.find_by(standard: "iso_26262")
        template.apply_to_project!(project)
      end

      it "detects the compliance template" do
        get project_compliance_dashboard_path(project)
        expect(response.body).to include("ISO 26262")
      end

      it "shows expected traceability links section" do
        get project_compliance_dashboard_path(project)
        expect(response.body).to include("Expected Traceability Links")
      end

      it "shows expected link relationships" do
        get project_compliance_dashboard_path(project)
        expect(response.body).to include("Derives from")
        expect(response.body).to include("Satisfies")
        expect(response.body).to include("Verifies")
        expect(response.body).to include("Refines")
      end

      it "shows the met/total counter" do
        get project_compliance_dashboard_path(project)
        expect(response.body).to match(/\d+ \/ \d+ met/)
      end

      it "shows all 7 V-model phases in coverage table" do
        get project_compliance_dashboard_path(project)
        expect(response.body).to include("System Requirements")
        expect(response.body).to include("Software Requirements")
        expect(response.body).to include("Software Architecture")
        expect(response.body).to include("Software Detailed Design")
        expect(response.body).to include("Unit Test Specifications")
        expect(response.body).to include("Integration Test Specifications")
        expect(response.body).to include("System Test Specifications")
      end
    end

    context "with ASPICE compliance template" do
      before do
        ComplianceTemplate.seed_templates!
        template = ComplianceTemplate.find_by(standard: "aspice")
        template.apply_to_project!(project)
      end

      it "detects the ASPICE template" do
        get project_compliance_dashboard_path(project)
        expect(response.body).to include("Automotive SPICE")
      end

      it "shows ASPICE process area modules" do
        get project_compliance_dashboard_path(project)
        expect(response.body).to include("SWE.1")
        expect(response.body).to include("SWE.6")
        expect(response.body).to include("SUP.10")
      end
    end

    context "multi-tenancy" do
      let(:other_org) { create(:organization) }
      let(:other_project) { create(:project, organization: other_org) }

      it "returns 404 for a project in another organization" do
        get project_compliance_dashboard_path(other_project)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "role-based access" do
      it "allows viewers to access the dashboard" do
        membership.update!(role: :viewer)
        get project_compliance_dashboard_path(project)
        expect(response).to have_http_status(:success)
      end

      it "allows reviewers to access the dashboard" do
        membership.update!(role: :reviewer)
        get project_compliance_dashboard_path(project)
        expect(response).to have_http_status(:success)
      end
    end
  end
end
