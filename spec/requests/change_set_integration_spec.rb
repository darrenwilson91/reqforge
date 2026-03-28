require "rails_helper"

RSpec.describe "Change Set Integration with Requirements", type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user) }
  let(:pm_user) { create(:user) }
  let(:author_user) { create(:user) }
  let(:reviewer_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:project) { create(:project, organization: organization) }
  let(:mod) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: mod) }
  let(:requirement) { create(:requirement, project: project, section: section, created_by: admin_user, title: "Original Title", body: "Original body") }

  before do
    create(:membership, user: admin_user, organization: organization, role: :admin)
    create(:membership, user: pm_user, organization: organization, role: :project_manager)
    create(:membership, user: author_user, organization: organization, role: :author)
    create(:membership, user: reviewer_user, organization: organization, role: :reviewer)
    create(:membership, user: viewer_user, organization: organization, role: :viewer)
  end

  # ─── ACTIVATE ───────────────────────────────────────────────────

  describe "POST /projects/:project_id/change_sets/:id/activate" do
    let(:change_set) { create(:change_set, project: project, created_by: admin_user) }

    it "sets the active change set in session" do
      sign_in admin_user
      post activate_project_change_set_path(project, change_set)
      expect(session[:active_change_set_id]).to eq(change_set.id)
    end

    it "redirects back with notice" do
      sign_in admin_user
      post activate_project_change_set_path(project, change_set)
      expect(response).to redirect_to(project_requirements_path(project))
      follow_redirect!
      expect(response.body).to include("Now editing in change set")
      expect(response.body).to include(change_set.title)
    end

    it "allows activation of draft change sets" do
      sign_in admin_user
      post activate_project_change_set_path(project, change_set)
      expect(session[:active_change_set_id]).to eq(change_set.id)
    end

    it "allows activation of open change sets" do
      sign_in admin_user
      change_set.update!(status: :open)
      post activate_project_change_set_path(project, change_set)
      expect(session[:active_change_set_id]).to eq(change_set.id)
    end

    it "allows activation of in_review change sets" do
      sign_in admin_user
      change_set.update!(status: :in_review)
      post activate_project_change_set_path(project, change_set)
      expect(session[:active_change_set_id]).to eq(change_set.id)
    end

    it "rejects activation of merged change sets" do
      sign_in admin_user
      change_set.update!(status: :merged)
      post activate_project_change_set_path(project, change_set)
      expect(session[:active_change_set_id]).to be_nil
      expect(response).to redirect_to(project_change_set_path(project, change_set))
    end

    it "rejects activation of closed change sets" do
      sign_in admin_user
      change_set.update!(status: :closed)
      post activate_project_change_set_path(project, change_set)
      expect(session[:active_change_set_id]).to be_nil
      expect(response).to redirect_to(project_change_set_path(project, change_set))
    end

    it "allows viewer to activate (show? policy)" do
      sign_in viewer_user
      post activate_project_change_set_path(project, change_set)
      expect(session[:active_change_set_id]).to eq(change_set.id)
    end

    it "redirects unauthenticated users" do
      post activate_project_change_set_path(project, change_set)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  # ─── DEACTIVATE ─────────────────────────────────────────────────

  describe "DELETE /projects/:project_id/change_sets/:id/deactivate" do
    let(:change_set) { create(:change_set, project: project, created_by: admin_user) }

    before do
      sign_in admin_user
      post activate_project_change_set_path(project, change_set)
    end

    it "clears the active change set from session" do
      delete deactivate_project_change_set_path(project, change_set)
      expect(session[:active_change_set_id]).to be_nil
    end

    it "redirects back with notice" do
      delete deactivate_project_change_set_path(project, change_set)
      expect(response).to redirect_to(project_change_set_path(project, change_set))
      follow_redirect!
      expect(response.body).to include("Exited change set editing mode")
    end

    it "allows viewer to deactivate" do
      sign_in viewer_user
      # Manually set session
      post activate_project_change_set_path(project, change_set)
      delete deactivate_project_change_set_path(project, change_set)
      expect(session[:active_change_set_id]).to be_nil
    end
  end

  # ─── AUTO-ACTIVATE ON CREATE ────────────────────────────────────

  describe "POST /projects/:project_id/change_sets (auto-activate)" do
    it "auto-activates the change set on creation" do
      sign_in admin_user
      post project_change_sets_path(project), params: { change_set: { title: "New Feature Work" } }
      cs = ChangeSet.last
      expect(session[:active_change_set_id]).to eq(cs.id)
    end

    it "shows activation notice on creation" do
      sign_in admin_user
      post project_change_sets_path(project), params: { change_set: { title: "New Feature Work" } }
      expect(response).to redirect_to(project_change_set_path(project, ChangeSet.last))
      follow_redirect!
      expect(response.body).to include("created and activated")
    end
  end

  # ─── EDITING WITH ACTIVE CHANGE SET ─────────────────────────────

  describe "PATCH /projects/:project_id/requirements/:id (with active change set)" do
    let(:change_set) { create(:change_set, project: project, created_by: admin_user) }

    before do
      sign_in admin_user
      post activate_project_change_set_path(project, change_set)
    end

    it "records the edit as a ChangeSetChange instead of updating the requirement" do
      original_title = requirement.title
      patch project_requirement_path(project, requirement), params: {
        requirement: { title: "New Title" }
      }
      requirement.reload
      expect(requirement.title).to eq(original_title) # NOT changed
      expect(change_set.change_set_changes.count).to eq(1)
    end

    it "creates a ChangeSetChange with correct attributes" do
      patch project_requirement_path(project, requirement), params: {
        requirement: { title: "Proposed Title", body: "Proposed body" }
      }
      change = change_set.change_set_changes.first
      expect(change.change_type).to eq("modified")
      expect(change.requirement).to eq(requirement)
      expect(change.before_snapshot["title"]).to eq("Original Title")
      expect(change.before_snapshot["body"]).to eq("Original body")
      expect(change.after_snapshot["title"]).to eq("Proposed Title")
      expect(change.after_snapshot["body"]).to eq("Proposed body")
    end

    it "redirects with a change set notice" do
      patch project_requirement_path(project, requirement), params: {
        requirement: { title: "New Title" }
      }
      expect(response).to redirect_to(project_requirement_path(project, requirement))
      follow_redirect!
      expect(response.body).to include("Changes recorded in change set")
      expect(response.body).to include(change_set.title)
    end

    it "updates an existing ChangeSetChange on second edit (upsert)" do
      # First edit
      patch project_requirement_path(project, requirement), params: {
        requirement: { title: "First Proposed Title" }
      }
      expect(change_set.change_set_changes.count).to eq(1)
      change = change_set.change_set_changes.first
      expect(change.after_snapshot["title"]).to eq("First Proposed Title")

      # Second edit
      patch project_requirement_path(project, requirement), params: {
        requirement: { title: "Second Proposed Title" }
      }
      expect(change_set.change_set_changes.count).to eq(1) # Still 1
      change.reload
      expect(change.before_snapshot["title"]).to eq("Original Title") # Preserved from first edit
      expect(change.after_snapshot["title"]).to eq("Second Proposed Title")
    end

    it "preserves the before_snapshot on subsequent edits" do
      patch project_requirement_path(project, requirement), params: {
        requirement: { title: "Edit 1" }
      }
      change = change_set.change_set_changes.first
      original_before = change.before_snapshot.dup

      patch project_requirement_path(project, requirement), params: {
        requirement: { title: "Edit 2" }
      }
      change.reload
      expect(change.before_snapshot).to eq(original_before)
    end

    it "records enum field changes" do
      patch project_requirement_path(project, requirement), params: {
        requirement: { priority: "should_have", asil_level: "asil_d" }
      }
      change = change_set.change_set_changes.first
      expect(change.after_snapshot["priority"]).to eq("should_have")
      expect(change.after_snapshot["asil_level"]).to eq("asil_d")
    end

    it "validates the proposed changes before recording" do
      patch project_requirement_path(project, requirement), params: {
        requirement: { title: "" }
      }
      expect(change_set.change_set_changes.count).to eq(0)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "includes module and section names in snapshots" do
      patch project_requirement_path(project, requirement), params: {
        requirement: { title: "New Title" }
      }
      change = change_set.change_set_changes.first
      expect(change.before_snapshot["module_name"]).to eq(mod.name)
      expect(change.before_snapshot["section_name"]).to eq(section.name)
    end

    it "does not enqueue impact analysis" do
      expect {
        patch project_requirement_path(project, requirement), params: {
          requirement: { title: "New Title" }
        }
      }.not_to have_enqueued_job(ImpactAnalysisJob)
    end
  end

  # ─── EDITING WITHOUT ACTIVE CHANGE SET ──────────────────────────

  describe "PATCH /projects/:project_id/requirements/:id (without active change set)" do
    it "updates the requirement directly as before" do
      sign_in admin_user
      patch project_requirement_path(project, requirement), params: {
        requirement: { title: "Updated Directly" }
      }
      requirement.reload
      expect(requirement.title).to eq("Updated Directly")
    end
  end

  # ─── SESSION CLEANUP ────────────────────────────────────────────

  describe "session cleanup on transition/merge" do
    let(:change_set) { create(:change_set, :approved, project: project, created_by: admin_user) }

    it "clears session when change set is merged" do
      sign_in pm_user
      # Set session manually
      post activate_project_change_set_path(project, change_set)
      # Add a change so merge has something to apply
      mod1 = create(:requirement_module, project: project)
      sec1 = create(:section, requirement_module: mod1)
      req1 = create(:requirement, project: project, section: sec1, created_by: admin_user)
      create(:change_set_change, :with_snapshots, change_set: change_set, requirement: req1, change_type: :modified)

      post merge_project_change_set_path(project, change_set)
      expect(session[:active_change_set_id]).to be_nil
    end

    it "clears session when change set is closed" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      post activate_project_change_set_path(project, cs)
      expect(session[:active_change_set_id]).to eq(cs.id)

      patch transition_status_project_change_set_path(project, cs, status: "closed")
      expect(session[:active_change_set_id]).to be_nil
    end
  end

  # ─── BANNER DISPLAY ─────────────────────────────────────────────

  describe "change set banner on requirement pages" do
    let(:change_set) { create(:change_set, project: project, created_by: admin_user, title: "Banner Test CS") }

    before do
      sign_in admin_user
      post activate_project_change_set_path(project, change_set)
    end

    it "shows banner on requirements index" do
      get project_requirements_path(project)
      expect(response.body).to include("Editing in Change Set:")
      expect(response.body).to include("Banner Test CS")
      expect(response.body).to include("Exit")
    end

    it "shows banner on requirement show page" do
      get project_requirement_path(project, requirement)
      expect(response.body).to include("Editing in Change Set:")
      expect(response.body).to include("Banner Test CS")
    end

    it "shows descriptive text about proposed changes" do
      get project_requirements_path(project)
      expect(response.body).to include("Requirement edits will be recorded as proposed changes")
    end

    it "does not show banner when no active change set" do
      delete deactivate_project_change_set_path(project, change_set)
      get project_requirements_path(project)
      expect(response.body).not_to include("Editing in Change Set:")
    end

    it "does not show banner for different project" do
      other_project = create(:project, organization: organization)
      get project_requirements_path(other_project)
      expect(response.body).not_to include("Editing in Change Set:")
    end
  end

  # ─── START CHANGE SET BUTTON ────────────────────────────────────

  describe "Start Change Set button" do
    it "shows on requirements index when no active change set" do
      sign_in admin_user
      get project_requirements_path(project)
      expect(response.body).to include("Start Change Set")
    end

    it "hides on requirements index when change set is active" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      post activate_project_change_set_path(project, cs)
      get project_requirements_path(project)
      expect(response.body).not_to include("Start Change Set")
    end

    it "shows on requirement detail when no active change set" do
      sign_in admin_user
      get project_requirement_path(project, requirement)
      expect(response.body).to include("Start Change Set")
    end

    it "hides on requirement detail when change set is active" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      post activate_project_change_set_path(project, cs)
      get project_requirement_path(project, requirement)
      expect(response.body).not_to include("Start Change Set")
    end

    it "links to new change set page" do
      sign_in admin_user
      get project_requirements_path(project)
      expect(response.body).to include(new_project_change_set_path(project))
    end
  end

  # ─── CHANGE SET SHOW PAGE BUTTONS ───────────────────────────────

  describe "activate/deactivate buttons on change set show page" do
    let(:change_set) { create(:change_set, project: project, created_by: admin_user) }

    it "shows Activate button when change set is not active" do
      sign_in admin_user
      get project_change_set_path(project, change_set)
      expect(response.body).to include("Activate")
      expect(response.body).to include(activate_project_change_set_path(project, change_set))
    end

    it "shows Edit Requirements and Deactivate buttons when change set is active" do
      sign_in admin_user
      post activate_project_change_set_path(project, change_set)
      get project_change_set_path(project, change_set)
      expect(response.body).to include("Edit Requirements")
      expect(response.body).to include("Deactivate")
      expect(response.body).to include(project_requirements_path(project))
    end

    it "does not show activate buttons for merged change sets" do
      sign_in admin_user
      change_set.update!(status: :merged)
      get project_change_set_path(project, change_set)
      expect(response.body).not_to include("Activate")
      expect(response.body).not_to include("Edit Requirements")
    end

    it "does not show activate buttons for closed change sets" do
      sign_in admin_user
      change_set.update!(status: :closed)
      get project_change_set_path(project, change_set)
      expect(response.body).not_to include("Activate")
      expect(response.body).not_to include("Edit Requirements")
    end
  end

  # ─── active_change_set HELPER ────────────────────────────────────

  describe "active_change_set scoping" do
    let(:change_set) { create(:change_set, project: project, created_by: admin_user) }

    it "returns nil when session has stale ID (change set merged)" do
      sign_in admin_user
      post activate_project_change_set_path(project, change_set)
      change_set.update!(status: :merged)
      get project_requirements_path(project)
      # Banner should not show for merged change set
      expect(response.body).not_to include("Editing in Change Set:")
    end

    it "returns nil when session has stale ID (change set closed)" do
      sign_in admin_user
      post activate_project_change_set_path(project, change_set)
      change_set.update!(status: :closed)
      get project_requirements_path(project)
      expect(response.body).not_to include("Editing in Change Set:")
    end

    it "does not show banner for a change set belonging to another project" do
      sign_in admin_user
      other_project = create(:project, organization: organization)
      other_cs = create(:change_set, project: other_project, created_by: admin_user)
      post activate_project_change_set_path(other_project, other_cs)

      get project_requirements_path(project)
      expect(response.body).not_to include("Editing in Change Set:")
    end
  end
end
