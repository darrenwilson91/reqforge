require "rails_helper"

RSpec.describe "Projects", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }

  before { sign_in user }

  describe "GET /projects" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        get projects_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it "renders the index page" do
      get projects_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Projects")
    end

    it "lists projects belonging to the current organization" do
      project = create(:project, organization: organization, name: "My Project")
      get projects_path
      expect(response.body).to include("My Project")
    end

    it "does not list projects from other organizations" do
      other_org = create(:organization)
      create(:project, organization: other_org, name: "Other Org Project")
      get projects_path
      expect(response.body).not_to include("Other Org Project")
    end

    it "shows empty state when no projects exist" do
      get projects_path
      expect(response.body).to include("No projects yet")
    end

    it "orders projects by most recently updated" do
      old_project = create(:project, organization: organization, name: "Old Project", updated_at: 2.days.ago)
      new_project = create(:project, organization: organization, name: "New Project", updated_at: 1.hour.ago)
      get projects_path
      body = response.body
      expect(body.index("New Project")).to be < body.index("Old Project")
    end

    context "when user is a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "allows access to the index" do
        get projects_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /projects/new" do
    it "renders the new project form" do
      get new_project_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("New Project")
      expect(response.body).to include("Create Project")
    end

    it "includes the attribute schema editor" do
      get new_project_path
      expect(response.body).to include("Custom Attributes")
      expect(response.body).to include("attribute-schema")
    end

    context "when compliance templates exist" do
      before do
        ComplianceTemplate.create!(name: "ISO 26262 — Functional Safety", standard: "iso_26262", template_data: ComplianceTemplate.iso_26262_template_data)
        ComplianceTemplate.create!(name: "Automotive SPICE", standard: "aspice", template_data: ComplianceTemplate.aspice_template_data)
      end

      it "shows the compliance template selector" do
        get new_project_path
        expect(response.body).to include("Compliance Template")
        expect(response.body).to include("template-select")
      end

      it "lists available templates" do
        get new_project_path
        expect(response.body).to include("ISO 26262")
        expect(response.body).to include("Automotive SPICE")
      end

      it "includes a blank option" do
        get new_project_path
        expect(response.body).to include("None — blank project")
      end

      it "does not show inactive templates" do
        ComplianceTemplate.find_by(standard: "aspice").update!(active: false)
        get new_project_path
        expect(response.body).to include("ISO 26262")
        expect(response.body).not_to include("ASPICE")
      end
    end

    context "when no compliance templates exist" do
      it "does not show the compliance template section" do
        get new_project_path
        expect(response.body).not_to include("Compliance Template")
      end
    end

    context "when user is an author (no create permission)" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :author) }

      it "denies access" do
        get new_project_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is a project manager" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :project_manager) }

      it "allows access" do
        get new_project_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "POST /projects" do
    let(:valid_params) do
      { project: { name: "Vehicle Control Unit", prefix: "VCU", description: "Main ECU project" } }
    end

    it "creates a project with valid params" do
      expect {
        post projects_path, params: valid_params
      }.to change(Project, :count).by(1)

      project = Project.last
      expect(project.name).to eq("Vehicle Control Unit")
      expect(project.prefix).to eq("VCU")
      expect(project.description).to eq("Main ECU project")
      expect(project.organization).to eq(organization)
    end

    it "redirects to the project show page on success" do
      post projects_path, params: valid_params
      expect(response).to redirect_to(project_path(Project.last))
      follow_redirect!
      expect(response.body).to include("Project created successfully")
    end

    it "scopes the project to the current organization" do
      post projects_path, params: valid_params
      expect(Project.last.organization).to eq(organization)
    end

    it "re-renders the form with errors for invalid params" do
      post projects_path, params: { project: { name: "", prefix: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "does not create a project with a blank name" do
      expect {
        post projects_path, params: { project: { name: "", prefix: "VCU" } }
      }.not_to change(Project, :count)
    end

    it "does not create a project with an invalid prefix" do
      expect {
        post projects_path, params: { project: { name: "Test", prefix: "lowercase" } }
      }.not_to change(Project, :count)
    end

    it "does not create a project with a duplicate prefix in the same org" do
      create(:project, organization: organization, prefix: "VCU")
      expect {
        post projects_path, params: valid_params
      }.not_to change(Project, :count)
    end

    it "saves attribute_schema from JSON string" do
      attrs = [{ "name" => "Safety Level", "attr_type" => "enum", "required" => true, "options" => "QM,ASIL-A" }]
      post projects_path, params: { project: { name: "Test", prefix: "TST", attribute_schema: attrs.to_json } }
      expect(Project.last.attribute_schema).to eq(attrs)
    end

    context "with compliance template" do
      let!(:template) { ComplianceTemplate.create!(name: "ISO 26262 — Functional Safety", standard: "iso_26262", template_data: ComplianceTemplate.iso_26262_template_data) }

      it "applies the selected template to the project" do
        post projects_path, params: valid_params.merge(compliance_template_id: template.id)
        project = Project.last
        expect(project.requirement_modules.count).to eq(7)
        expect(project.requirement_modules.pluck(:name)).to include("System Requirements", "Software Requirements")
      end

      it "creates sections from the template" do
        post projects_path, params: valid_params.merge(compliance_template_id: template.id)
        project = Project.last
        sections = Section.where(requirement_module: project.requirement_modules)
        expect(sections.count).to eq(18)
      end

      it "sets attribute_schema from the template" do
        post projects_path, params: valid_params.merge(compliance_template_id: template.id)
        project = Project.last
        expect(project.attribute_schema.length).to eq(4)
        expect(project.attribute_schema.map { |a| a["name"] }).to include("Safety Goal", "ASIL Allocation")
      end

      it "ignores blank compliance_template_id" do
        post projects_path, params: valid_params.merge(compliance_template_id: "")
        project = Project.last
        expect(project.requirement_modules.count).to eq(0)
      end

      it "ignores invalid compliance_template_id" do
        post projects_path, params: valid_params.merge(compliance_template_id: 999999)
        project = Project.last
        expect(project.requirement_modules.count).to eq(0)
      end

      it "ignores inactive templates" do
        template.update!(active: false)
        post projects_path, params: valid_params.merge(compliance_template_id: template.id)
        project = Project.last
        expect(project.requirement_modules.count).to eq(0)
      end
    end

    context "with ASPICE compliance template" do
      let!(:template) { ComplianceTemplate.create!(name: "Automotive SPICE", standard: "aspice", template_data: ComplianceTemplate.aspice_template_data) }

      it "applies the ASPICE template" do
        post projects_path, params: valid_params.merge(compliance_template_id: template.id)
        project = Project.last
        expect(project.requirement_modules.count).to eq(9)
        expect(project.requirement_modules.pluck(:name)).to include("SWE.1 — Software Requirements Analysis")
      end
    end

    context "when user is an author (no create permission)" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :author) }

      it "denies project creation" do
        expect {
          post projects_path, params: valid_params
        }.not_to change(Project, :count)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is a project manager" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :project_manager) }

      it "allows project creation" do
        expect {
          post projects_path, params: valid_params
        }.to change(Project, :count).by(1)
      end
    end
  end

  describe "GET /projects/:id" do
    let!(:project) { create(:project, organization: organization, name: "My Project", prefix: "MP") }

    it "renders the project show page" do
      get project_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("My Project")
      expect(response.body).to include("MP")
    end

    it "shows project stats" do
      get project_path(project)
      expect(response.body).to include("Modules")
      expect(response.body).to include("Requirements")
    end

    it "shows modules and sections" do
      mod = create(:requirement_module, project: project, name: "System Requirements")
      create(:section, requirement_module: mod, name: "Functional")
      get project_path(project)
      expect(response.body).to include("System Requirements")
      expect(response.body).to include("Functional")
    end

    it "shows empty state when no modules exist" do
      get project_path(project)
      expect(response.body).to include("No modules yet")
    end

    it "shows custom attributes when defined" do
      project.update!(attribute_schema: [{ "name" => "Safety Level", "attr_type" => "enum", "required" => true }])
      get project_path(project)
      expect(response.body).to include("Custom Attributes")
      expect(response.body).to include("Safety Level")
    end

    it "includes edit and delete actions" do
      get project_path(project)
      expect(response.body).to include("Edit")
      expect(response.body).to include("Delete")
    end

    it "includes breadcrumb navigation" do
      get project_path(project)
      expect(response.body).to include("Projects")
    end

    it "returns 404 for projects in other organizations" do
      other_org = create(:organization)
      other_project = create(:project, organization: other_org)
      get project_path(other_project)
      expect(response).to have_http_status(:not_found)
    end

    context "when user is a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "allows access to show" do
        get project_path(project)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /projects/:id/edit" do
    let!(:project) { create(:project, organization: organization, name: "My Project") }

    it "renders the edit project form" do
      get edit_project_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Edit Project")
      expect(response.body).to include("My Project")
    end

    it "shows the status selector for existing projects" do
      get edit_project_path(project)
      expect(response.body).to include("Status")
    end

    it "does not show the compliance template selector on edit" do
      ComplianceTemplate.create!(name: "ISO 26262", standard: "iso_26262", template_data: ComplianceTemplate.iso_26262_template_data)
      get edit_project_path(project)
      expect(response.body).not_to include("Compliance Template")
    end

    context "when user is a viewer (no edit permission)" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "denies access" do
        get edit_project_path(project)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is a project manager" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :project_manager) }

      it "allows access" do
        get edit_project_path(project)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "PATCH /projects/:id" do
    let!(:project) { create(:project, organization: organization, name: "Old Name", prefix: "OLD") }

    it "updates the project with valid params" do
      patch project_path(project), params: { project: { name: "New Name" } }
      expect(project.reload.name).to eq("New Name")
    end

    it "redirects to the project show page on success" do
      patch project_path(project), params: { project: { name: "New Name" } }
      expect(response).to redirect_to(project_path(project))
      follow_redirect!
      expect(response.body).to include("Project updated successfully")
    end

    it "can update the project status" do
      patch project_path(project), params: { project: { status: "archived" } }
      expect(project.reload.status).to eq("archived")
    end

    it "re-renders the form with errors for invalid params" do
      patch project_path(project), params: { project: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "updates attribute_schema from JSON string" do
      attrs = [{ "name" => "Priority", "attr_type" => "text", "required" => false }]
      patch project_path(project), params: { project: { attribute_schema: attrs.to_json } }
      expect(project.reload.attribute_schema).to eq(attrs)
    end

    context "when user is a viewer (no update permission)" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "denies the update" do
        patch project_path(project), params: { project: { name: "Hacked" } }
        expect(response).to redirect_to(root_path)
        expect(project.reload.name).to eq("Old Name")
      end
    end

    context "when user is a project manager" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :project_manager) }

      it "allows the update" do
        patch project_path(project), params: { project: { name: "Updated" } }
        expect(project.reload.name).to eq("Updated")
      end
    end
  end

  describe "DELETE /projects/:id" do
    let!(:project) { create(:project, organization: organization, name: "Doomed Project") }

    it "deletes the project" do
      expect {
        delete project_path(project)
      }.to change(Project, :count).by(-1)
    end

    it "redirects to the projects index with a success message" do
      delete project_path(project)
      expect(response).to redirect_to(projects_path)
      expect(flash[:notice]).to eq("Project deleted successfully.")
    end

    context "when user is a project manager (no destroy permission)" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :project_manager) }

      it "denies deletion" do
        expect {
          delete project_path(project)
        }.not_to change(Project, :count)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is a viewer (no destroy permission)" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "denies deletion" do
        expect {
          delete project_path(project)
        }.not_to change(Project, :count)
      end
    end
  end
end
