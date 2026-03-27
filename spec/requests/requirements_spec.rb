require "rails_helper"

RSpec.describe "Requirements", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization) }
  let(:req_module) { create(:requirement_module, project: project, name: "System Requirements") }
  let(:section) { create(:section, requirement_module: req_module, name: "Functional") }

  before { sign_in user }

  # Helper to create a requirement within the test project
  def create_requirement(**attrs)
    create(:requirement, project: project, section: section, created_by: user, **attrs)
  end

  describe "GET /projects/:project_id/requirements" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        get project_requirements_path(project)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it "renders the index page" do
      get project_requirements_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Requirements")
    end

    it "lists requirements belonging to the project" do
      req = create_requirement(title: "Brake system shall activate within 100ms")
      get project_requirements_path(project)
      expect(response.body).to include("Brake system shall activate within 100ms")
      expect(response.body).to include(req.uid)
    end

    it "shows empty state when no requirements exist" do
      get project_requirements_path(project)
      expect(response.body).to include("No requirements yet")
    end

    it "does not show requirements from other projects" do
      other_project = create(:project, organization: organization)
      other_section = create(:section, requirement_module: create(:requirement_module, project: other_project))
      create(:requirement, project: other_project, section: other_section, created_by: user, title: "Other Project Req")
      get project_requirements_path(project)
      expect(response.body).not_to include("Other Project Req")
    end

    context "filtering" do
      let!(:functional_req) { create_requirement(title: "Functional Req", requirement_type: :functional, status: :draft) }
      let!(:safety_req) { create_requirement(title: "Safety Req", requirement_type: :safety, status: :approved) }

      it "filters by status" do
        get project_requirements_path(project, status: "approved")
        # Count assertion — tree panel shows all requirements, so we check the table count
        expect(response.body).to include("1 requirement")
      end

      it "filters by requirement type" do
        get project_requirements_path(project, requirement_type: "safety")
        expect(response.body).to include("1 requirement")
      end

      it "filters by full-text search" do
        get project_requirements_path(project, q: "Safety")
        expect(response.body).to include("1 requirement")
      end

      it "shows all requirements when no filter is applied" do
        get project_requirements_path(project)
        expect(response.body).to include("2 requirements")
      end
    end

    context "multi-tenancy" do
      it "returns 404 for a project in another organization" do
        other_org = create(:organization)
        other_project = create(:project, organization: other_org)
        get project_requirements_path(other_project)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /projects/:project_id/requirements/new" do
    it "renders the new requirement form" do
      get new_project_requirement_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("New Requirement")
      expect(response.body).to include("Create Requirement")
    end

    it "pre-selects section when section_id param is provided" do
      get new_project_requirement_path(project, section_id: section.id)
      expect(response).to have_http_status(:success)
    end

    context "when user is a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "denies access" do
        get new_project_requirement_path(project)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /projects/:project_id/requirements" do
    let(:valid_params) do
      {
        requirement: {
          title: "The braking system shall achieve full stop within 50m at 100km/h",
          body: "This requirement defines the maximum stopping distance.",
          section_id: section.id,
          requirement_type: "functional",
          status: "draft",
          priority: "must_have",
          asil_level: "asil_d"
        }
      }
    end

    it "creates a requirement with valid params" do
      expect {
        post project_requirements_path(project), params: valid_params
      }.to change(Requirement, :count).by(1)

      req = Requirement.last
      expect(req.title).to eq("The braking system shall achieve full stop within 50m at 100km/h")
      expect(req.asil_level).to eq("asil_d")
      expect(req.created_by).to eq(user)
      expect(response).to redirect_to(project_requirement_path(project, req))
    end

    it "auto-generates a UID using the project prefix" do
      post project_requirements_path(project), params: valid_params
      req = Requirement.last
      expect(req.uid).to start_with(project.prefix)
    end

    it "increments UID sequence" do
      create_requirement
      post project_requirements_path(project), params: valid_params
      req = Requirement.last
      expect(req.uid).to eq("#{project.prefix}-0002")
    end

    it "does not create a requirement with missing title" do
      invalid_params = valid_params.deep_merge(requirement: { title: "" })
      expect {
        post project_requirements_path(project), params: invalid_params
      }.not_to change(Requirement, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "handles custom_attributes as a nested hash" do
      params_with_attrs = valid_params.deep_merge(
        requirement: { custom_attributes: { "Safety Classification" => "ASIL-D" } }
      )
      post project_requirements_path(project), params: params_with_attrs
      req = Requirement.last
      expect(req.custom_attributes["Safety Classification"]).to eq("ASIL-D")
    end

    it "creates a PaperTrail version on create" do
      post project_requirements_path(project), params: valid_params
      req = Requirement.last
      expect(req.versions.count).to eq(1)
      expect(req.versions.last.event).to eq("create")
    end

    context "when user is a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "denies access" do
        expect {
          post project_requirements_path(project), params: valid_params
        }.not_to change(Requirement, :count)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is an author" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :author) }

      it "allows creation" do
        expect {
          post project_requirements_path(project), params: valid_params
        }.to change(Requirement, :count).by(1)
      end
    end
  end

  describe "GET /projects/:project_id/requirements/:id" do
    let!(:requirement) { create_requirement(title: "ABS shall prevent wheel lock", body: "Anti-lock braking system requirement") }

    it "renders the requirement detail" do
      get project_requirement_path(project, requirement)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(requirement.uid)
      expect(response.body).to include("ABS shall prevent wheel lock")
      expect(response.body).to include("Anti-lock braking system requirement")
    end

    it "shows breadcrumbs" do
      get project_requirement_path(project, requirement)
      expect(response.body).to include("Projects")
      expect(response.body).to include(project.name)
      expect(response.body).to include("Requirements")
      expect(response.body).to include(requirement.uid)
    end

    it "shows attribute badges" do
      get project_requirement_path(project, requirement)
      expect(response.body).to include("Draft")
      expect(response.body).to include("Functional")
      expect(response.body).to include("Must have")
    end

    it "shows module and section in metadata" do
      get project_requirement_path(project, requirement)
      expect(response.body).to include("System Requirements")
      expect(response.body).to include("Functional")
    end

    it "shows the creator name" do
      get project_requirement_path(project, requirement)
      expect(response.body).to include(user.full_name)
    end

    it "shows version history section" do
      get project_requirement_path(project, requirement)
      expect(response.body).to include("Version History")
    end

    it "shows the hierarchy tree panel" do
      get project_requirement_path(project, requirement)
      expect(response.body).to include("System Requirements")
    end

    it "shows custom attributes when present" do
      requirement.update!(custom_attributes: { "Verification Method" => "Test" })
      get project_requirement_path(project, requirement)
      expect(response.body).to include("Verification Method")
      expect(response.body).to include("Test")
    end

    it "returns 404 for a requirement in another project" do
      other_project = create(:project, organization: organization)
      get project_requirement_path(other_project, requirement)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /projects/:project_id/requirements/:id/edit" do
    let!(:requirement) { create_requirement(title: "Original Title") }

    it "renders the edit form" do
      get edit_project_requirement_path(project, requirement)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Original Title")
    end

    context "when user is a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "denies access" do
        get edit_project_requirement_path(project, requirement)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /projects/:project_id/requirements/:id" do
    let!(:requirement) { create_requirement(title: "Original Title", body: "Original body") }

    it "updates the requirement with valid params" do
      patch project_requirement_path(project, requirement), params: {
        requirement: { title: "Updated Title" }
      }
      expect(response).to redirect_to(project_requirement_path(project, requirement))
      expect(requirement.reload.title).to eq("Updated Title")
    end

    it "updates status, priority, and ASIL level" do
      patch project_requirement_path(project, requirement), params: {
        requirement: { priority: "should_have", asil_level: "asil_c" }
      }
      requirement.reload
      expect(requirement.priority).to eq("should_have")
      expect(requirement.asil_level).to eq("asil_c")
    end

    it "creates a PaperTrail version on update" do
      initial_version_count = requirement.versions.count
      patch project_requirement_path(project, requirement), params: {
        requirement: { title: "Changed Title" }
      }
      expect(requirement.reload.versions.count).to eq(initial_version_count + 1)
      expect(requirement.versions.last.event).to eq("update")
    end

    it "rejects update with blank title" do
      patch project_requirement_path(project, requirement), params: {
        requirement: { title: "" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(requirement.reload.title).to eq("Original Title")
    end

    it "updates custom_attributes" do
      patch project_requirement_path(project, requirement), params: {
        requirement: { custom_attributes: { "Safety Classification" => "ASIL-B" } }
      }
      expect(requirement.reload.custom_attributes["Safety Classification"]).to eq("ASIL-B")
    end

    context "when user is a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "denies access" do
        patch project_requirement_path(project, requirement), params: {
          requirement: { title: "Hacked Title" }
        }
        expect(response).to redirect_to(root_path)
        expect(requirement.reload.title).to eq("Original Title")
      end
    end
  end

  describe "DELETE /projects/:project_id/requirements/:id" do
    let!(:requirement) { create_requirement(title: "To be deleted") }

    it "destroys the requirement and redirects" do
      expect {
        delete project_requirement_path(project, requirement)
      }.to change(Requirement, :count).by(-1)
      expect(response).to redirect_to(project_requirements_path(project))
    end

    context "when user is an author" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :author) }

      it "denies deletion" do
        expect {
          delete project_requirement_path(project, requirement)
        }.not_to change(Requirement, :count)
        expect(response).to redirect_to(root_path)
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

  describe "PATCH /projects/:project_id/requirements/:id/transition_status" do
    let!(:requirement) { create_requirement(status: :draft) }

    it "transitions from draft to in_review" do
      patch transition_status_project_requirement_path(project, requirement), params: { status: "in_review" }
      expect(response).to redirect_to(project_requirement_path(project, requirement))
      expect(requirement.reload.status).to eq("in_review")
      expect(flash[:notice]).to include("In review")
    end

    it "rejects invalid transition from draft to approved" do
      patch transition_status_project_requirement_path(project, requirement), params: { status: "approved" }
      expect(response).to redirect_to(project_requirement_path(project, requirement))
      expect(requirement.reload.status).to eq("draft")
      expect(flash[:alert]).to be_present
    end

    it "allows transition to obsolete from any status" do
      patch transition_status_project_requirement_path(project, requirement), params: { status: "obsolete" }
      expect(requirement.reload.status).to eq("obsolete")
    end

    it "allows restoring from obsolete to draft" do
      requirement.update_column(:status, 5) # obsolete
      patch transition_status_project_requirement_path(project, requirement), params: { status: "draft" }
      expect(requirement.reload.status).to eq("draft")
    end

    it "creates a PaperTrail version on status transition" do
      initial_count = requirement.versions.count
      patch transition_status_project_requirement_path(project, requirement), params: { status: "in_review" }
      expect(requirement.reload.versions.count).to eq(initial_count + 1)
    end

    it "walks through the full happy path workflow" do
      # draft -> in_review -> approved -> implemented -> verified
      patch transition_status_project_requirement_path(project, requirement), params: { status: "in_review" }
      expect(requirement.reload.status).to eq("in_review")

      patch transition_status_project_requirement_path(project, requirement), params: { status: "approved" }
      expect(requirement.reload.status).to eq("approved")

      patch transition_status_project_requirement_path(project, requirement), params: { status: "implemented" }
      expect(requirement.reload.status).to eq("implemented")

      patch transition_status_project_requirement_path(project, requirement), params: { status: "verified" }
      expect(requirement.reload.status).to eq("verified")
    end

    context "when user is a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "denies access" do
        patch transition_status_project_requirement_path(project, requirement), params: { status: "in_review" }
        expect(response).to redirect_to(root_path)
        expect(requirement.reload.status).to eq("draft")
      end
    end
  end

  describe "POST /projects/:project_id/requirements/:id/analyze_quality" do
    let!(:requirement) { create_requirement(title: "System shall activate brakes", body: "The braking system shall activate within 100ms of pedal input.") }

    it "enqueues a QualityAnalysisJob" do
      expect {
        post analyze_quality_project_requirement_path(project, requirement)
      }.to have_enqueued_job(QualityAnalysisJob).with(requirement.id)
    end

    it "creates a running AiAnalysisResult record" do
      post analyze_quality_project_requirement_path(project, requirement)
      result = AiAnalysisResult.find_by(requirement: requirement, analysis_type: "quality_analysis")
      expect(result).to be_present
      expect(result.status).to eq("running")
    end

    it "redirects to the requirement page for HTML requests" do
      post analyze_quality_project_requirement_path(project, requirement)
      expect(response).to redirect_to(project_requirement_path(project, requirement))
      expect(flash[:notice]).to include("Quality analysis started")
    end

    it "responds with Turbo Stream when requested" do
      post analyze_quality_project_requirement_path(project, requirement),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("ai_analysis_panel")
      expect(response.body).to include("Analyzing")
    end

    it "re-analyzes when a previous result exists" do
      AiAnalysisResult.store_result!(requirement, "quality_analysis", { "overall_score" => 85 })
      expect {
        post analyze_quality_project_requirement_path(project, requirement)
      }.to have_enqueued_job(QualityAnalysisJob).with(requirement.id)
      result = AiAnalysisResult.find_by(requirement: requirement, analysis_type: "quality_analysis")
      expect(result.status).to eq("running")
    end

    context "when user is a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "denies access" do
        post analyze_quality_project_requirement_path(project, requirement)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is an author" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :author) }

      it "allows access" do
        post analyze_quality_project_requirement_path(project, requirement)
        expect(response).to redirect_to(project_requirement_path(project, requirement))
      end
    end

    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        post analyze_quality_project_requirement_path(project, requirement)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /projects/:project_id/requirements/:id/suggest_links" do
    let!(:requirement) { create_requirement(title: "System shall activate brakes", body: "The braking system shall activate within 100ms of pedal input.") }

    it "enqueues a LinkSuggestionJob" do
      expect {
        post suggest_links_project_requirement_path(project, requirement)
      }.to have_enqueued_job(LinkSuggestionJob).with(requirement.id)
    end

    it "creates a running AiAnalysisResult record" do
      post suggest_links_project_requirement_path(project, requirement)
      result = AiAnalysisResult.find_by(requirement: requirement, analysis_type: "link_suggestion")
      expect(result).to be_present
      expect(result.status).to eq("running")
    end

    it "redirects to the requirement page for HTML requests" do
      post suggest_links_project_requirement_path(project, requirement)
      expect(response).to redirect_to(project_requirement_path(project, requirement))
      expect(flash[:notice]).to include("Link suggestion analysis started")
    end

    it "responds with Turbo Stream when requested" do
      post suggest_links_project_requirement_path(project, requirement),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("ai_analysis_panel")
    end

    it "re-analyzes when a previous result exists" do
      AiAnalysisResult.store_result!(requirement, "link_suggestion", { "suggestions" => [] })
      expect {
        post suggest_links_project_requirement_path(project, requirement)
      }.to have_enqueued_job(LinkSuggestionJob).with(requirement.id)
      result = AiAnalysisResult.find_by(requirement: requirement, analysis_type: "link_suggestion")
      expect(result.status).to eq("running")
    end

    context "when user is a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "denies access" do
        post suggest_links_project_requirement_path(project, requirement)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is an author" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :author) }

      it "allows access" do
        post suggest_links_project_requirement_path(project, requirement)
        expect(response).to redirect_to(project_requirement_path(project, requirement))
      end
    end

    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        post suggest_links_project_requirement_path(project, requirement)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
