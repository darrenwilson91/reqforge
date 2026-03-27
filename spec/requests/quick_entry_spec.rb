require "rails_helper"

RSpec.describe "Quick Entry", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization) }
  let(:req_module) { create(:requirement_module, project: project, name: "System Requirements") }
  let(:section) { create(:section, requirement_module: req_module, name: "Functional") }

  before { sign_in user }

  describe "GET /projects/:project_id/requirements/quick_entry" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        get quick_entry_project_requirements_path(project)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it "renders the quick entry page" do
      get quick_entry_project_requirements_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Quick Entry")
    end

    it "shows the project name and prefix" do
      get quick_entry_project_requirements_path(project)
      expect(response.body).to include(project.name)
      expect(response.body).to include(project.prefix)
    end

    it "shows breadcrumbs" do
      get quick_entry_project_requirements_path(project)
      expect(response.body).to include("Projects")
      expect(response.body).to include("Requirements")
      expect(response.body).to include("Quick Entry")
    end

    it "shows section selector dropdown" do
      section # create
      get quick_entry_project_requirements_path(project)
      expect(response.body).to include("Target Section")
      expect(response.body).to include("#{req_module.name} &gt; #{section.name}")
    end

    it "shows empty state when no section is selected" do
      get quick_entry_project_requirements_path(project)
      expect(response.body).to include("Select a section to begin")
    end

    context "with section selected" do
      let!(:req1) { create(:requirement, project: project, section: section, created_by: user, title: "Brakes shall activate within 100ms") }
      let!(:req2) { create(:requirement, project: project, section: section, created_by: user, title: "ABS shall prevent wheel lock") }

      it "shows existing requirements in the section" do
        get quick_entry_project_requirements_path(project, section_id: section.id)
        expect(response.body).to include("Brakes shall activate within 100ms")
        expect(response.body).to include("ABS shall prevent wheel lock")
        expect(response.body).to include(req1.uid)
        expect(response.body).to include(req2.uid)
      end

      it "shows the text input area" do
        get quick_entry_project_requirements_path(project, section_id: section.id)
        expect(response.body).to include("Type a requirement and press Enter")
      end

      it "shows keyboard hint badges" do
        get quick_entry_project_requirements_path(project, section_id: section.id)
        expect(response.body).to include("save &amp; next")
        expect(response.body).to include("new line")
        expect(response.body).to include("set attributes")
        expect(response.body).to include("navigate rows")
      end

      it "shows the floating action bar with session counter" do
        get quick_entry_project_requirements_path(project, section_id: section.id)
        expect(response.body).to include("entered this session")
        expect(response.body).to include("in section")
      end

      it "shows total count of requirements in the section" do
        get quick_entry_project_requirements_path(project, section_id: section.id)
        expect(response.body).to include(">#{section.requirements.count}<")
      end

      it "does not show requirements from other sections" do
        other_section = create(:section, requirement_module: req_module, name: "Non-Functional")
        create(:requirement, project: project, section: other_section, created_by: user, title: "Invisible Req")
        get quick_entry_project_requirements_path(project, section_id: section.id)
        expect(response.body).not_to include("Invisible Req")
      end

      it "shows the Done button linking to requirements list" do
        get quick_entry_project_requirements_path(project, section_id: section.id)
        expect(response.body).to include("Done")
        expect(response.body).to include(project_requirements_path(project))
      end

      it "shows the Back to List link" do
        get quick_entry_project_requirements_path(project, section_id: section.id)
        expect(response.body).to include("Back to List")
      end
    end

    context "with no modules or sections" do
      it "shows a message about creating modules first" do
        get quick_entry_project_requirements_path(project)
        expect(response.body).to include("No modules or sections exist yet")
      end
    end

    context "when user is a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "allows access (show? policy)" do
        get quick_entry_project_requirements_path(project)
        expect(response).to have_http_status(:success)
      end
    end

    it "does not show requirements from other projects" do
      other_org = create(:organization)
      other_project = create(:project, organization: other_org)
      get quick_entry_project_requirements_path(other_project)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /projects/:project_id/requirements/quick_create" do
    it "creates a requirement with the given title" do
      expect {
        post quick_create_project_requirements_path(project), params: { title: "System shall log all events", section_id: section.id }
      }.to change(Requirement, :count).by(1)
      req = Requirement.last
      expect(req.title).to eq("System shall log all events")
      expect(req.section).to eq(section)
      expect(req.project).to eq(project)
      expect(req.created_by).to eq(user)
    end

    it "auto-generates a UID with the project prefix" do
      post quick_create_project_requirements_path(project), params: { title: "Brake force shall be proportional", section_id: section.id }
      req = Requirement.last
      expect(req.uid).to start_with(project.prefix)
      expect(req.uid).to match(/\A#{Regexp.escape(project.prefix)}-\d+\z/)
    end

    it "generates sequential UIDs" do
      post quick_create_project_requirements_path(project), params: { title: "First requirement", section_id: section.id }
      post quick_create_project_requirements_path(project), params: { title: "Second requirement", section_id: section.id }
      uids = Requirement.order(:id).pluck(:uid)
      first_num = uids.first.split("-").last.to_i
      second_num = uids.last.split("-").last.to_i
      expect(second_num).to eq(first_num + 1)
    end

    it "assigns default attributes when none specified" do
      post quick_create_project_requirements_path(project), params: { title: "Default attrs req", section_id: section.id }
      req = Requirement.last
      expect(req.requirement_type).to eq("functional")
      expect(req.priority).to eq("must_have")
      expect(req.asil_level).to eq("qm")
    end

    it "accepts custom requirement_type" do
      post quick_create_project_requirements_path(project), params: {
        title: "Safety requirement", section_id: section.id, requirement_type: "safety"
      }
      expect(Requirement.last.requirement_type).to eq("safety")
    end

    it "accepts custom priority" do
      post quick_create_project_requirements_path(project), params: {
        title: "High priority req", section_id: section.id, priority: "could_have"
      }
      expect(Requirement.last.priority).to eq("could_have")
    end

    it "accepts custom asil_level" do
      post quick_create_project_requirements_path(project), params: {
        title: "ASIL D requirement", section_id: section.id, asil_level: "asil_d"
      }
      expect(Requirement.last.asil_level).to eq("asil_d")
    end

    it "accepts all three custom attributes together" do
      post quick_create_project_requirements_path(project), params: {
        title: "Full custom req", section_id: section.id,
        requirement_type: "non_functional", priority: "should_have", asil_level: "asil_b"
      }
      req = Requirement.last
      expect(req.requirement_type).to eq("non_functional")
      expect(req.priority).to eq("should_have")
      expect(req.asil_level).to eq("asil_b")
    end

    it "strips whitespace from title" do
      post quick_create_project_requirements_path(project), params: { title: "  Padded title  ", section_id: section.id }
      expect(Requirement.last.title).to eq("Padded title")
    end

    it "scopes requirement to the selected section" do
      other_section = create(:section, requirement_module: req_module, name: "Interface")
      post quick_create_project_requirements_path(project), params: { title: "Interface req", section_id: other_section.id }
      expect(Requirement.last.section).to eq(other_section)
    end

    it "redirects to quick entry for HTML requests on success" do
      post quick_create_project_requirements_path(project), params: { title: "HTML req", section_id: section.id }
      expect(response).to redirect_to(quick_entry_project_requirements_path(project, section_id: section.id))
    end

    it "returns turbo stream on success for turbo requests" do
      post quick_create_project_requirements_path(project),
        params: { title: "Turbo req", section_id: section.id },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("quick-entry-list")
      expect(response.body).to include("Turbo req")
    end

    it "includes the UID in the turbo stream response" do
      post quick_create_project_requirements_path(project),
        params: { title: "UID check", section_id: section.id },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
      req = Requirement.last
      expect(response.body).to include(req.uid)
    end

    it "creates a PaperTrail version" do
      post quick_create_project_requirements_path(project), params: { title: "Versioned req", section_id: section.id }
      req = Requirement.last
      expect(req.versions.count).to eq(1)
      expect(req.versions.last.event).to eq("create")
    end

    it "returns unprocessable entity for blank title via turbo" do
      post quick_create_project_requirements_path(project),
        params: { title: "", section_id: section.id },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "does not create a requirement with blank title" do
      expect {
        post quick_create_project_requirements_path(project), params: { title: "", section_id: section.id }
      }.not_to change(Requirement, :count)
    end

    it "redirects with alert for blank title via HTML" do
      post quick_create_project_requirements_path(project), params: { title: "", section_id: section.id }
      expect(response).to redirect_to(quick_entry_project_requirements_path(project))
      expect(flash[:alert]).to be_present
    end

    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        post quick_create_project_requirements_path(project), params: { title: "Unauth req", section_id: section.id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "denies access" do
        expect {
          post quick_create_project_requirements_path(project), params: { title: "Viewer req", section_id: section.id }
        }.not_to change(Requirement, :count)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is an author" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :author) }

      it "denies access (quick_create uses project update? policy)" do
        expect {
          post quick_create_project_requirements_path(project), params: { title: "Author req", section_id: section.id }
        }.not_to change(Requirement, :count)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is a reviewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :reviewer) }

      it "denies access" do
        expect {
          post quick_create_project_requirements_path(project), params: { title: "Reviewer req", section_id: section.id }
        }.not_to change(Requirement, :count)
        expect(response).to redirect_to(root_path)
      end
    end

    it "does not allow creation in a cross-org project" do
      other_org = create(:organization)
      other_project = create(:project, organization: other_org)
      other_module = create(:requirement_module, project: other_project)
      other_section = create(:section, requirement_module: other_module)
      expect {
        post quick_create_project_requirements_path(other_project), params: { title: "Cross org", section_id: other_section.id }
      }.not_to change(Requirement, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /projects/:project_id/requirements/:id (from quick entry)" do
    let!(:requirement) { create(:requirement, project: project, section: section, created_by: user, title: "To be deleted") }

    it "deletes the requirement" do
      expect {
        delete project_requirement_path(project, requirement)
      }.to change(Requirement, :count).by(-1)
    end

    it "redirects to requirements index for HTML requests" do
      delete project_requirement_path(project, requirement)
      expect(response).to redirect_to(project_requirements_path(project))
    end

    context "when user is a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "denies deletion" do
        expect {
          delete project_requirement_path(project, requirement)
        }.not_to change(Requirement, :count)
      end
    end

    context "when user is an author" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :author) }

      it "denies deletion (only PM/admin can delete)" do
        expect {
          delete project_requirement_path(project, requirement)
        }.not_to change(Requirement, :count)
      end
    end

    context "when user is a project_manager" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :project_manager) }

      it "allows deletion" do
        expect {
          delete project_requirement_path(project, requirement)
        }.to change(Requirement, :count).by(-1)
      end
    end
  end
end
