require "rails_helper"

RSpec.describe "ChangeSets", type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user) }
  let(:pm_user) { create(:user) }
  let(:author_user) { create(:user) }
  let(:reviewer_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:project) { create(:project, organization: organization) }

  before do
    create(:membership, user: admin_user, organization: organization, role: :admin)
    create(:membership, user: pm_user, organization: organization, role: :project_manager)
    create(:membership, user: author_user, organization: organization, role: :author)
    create(:membership, user: reviewer_user, organization: organization, role: :reviewer)
    create(:membership, user: viewer_user, organization: organization, role: :viewer)
  end

  def create_change_with_requirement(change_set, change_type: :modified)
    mod = create(:requirement_module, project: project)
    section = create(:section, requirement_module: mod)
    req = create(:requirement, project: project, section: section, created_by: admin_user)
    create(:change_set_change, :with_snapshots, change_set: change_set, requirement: req, change_type: change_type)
  end

  # ─── INDEX ─────────────────────────────────────────────────────

  describe "GET /projects/:project_id/change_sets" do
    it "redirects unauthenticated users" do
      get project_change_sets_path(project)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the index page" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      get project_change_sets_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(cs.title)
    end

    it "shows empty state when no change sets exist" do
      sign_in admin_user
      get project_change_sets_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("No change sets yet")
    end

    it "shows change counts" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      create_change_with_requirement(cs, change_type: :created)
      create_change_with_requirement(cs, change_type: :modified)
      get project_change_sets_path(project)
      expect(response.body).to include("+1")
      expect(response.body).to include("~1")
    end

    it "shows approval progress" do
      sign_in admin_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      create(:change_set_approval, :approved, change_set: cs, user: reviewer_user)
      create(:change_set_approval, change_set: cs, user: pm_user)
      get project_change_sets_path(project)
      expect(response.body).to include("50%")
      expect(response.body).to include("1/2 reviewed")
    end

    it "returns 404 for cross-organization projects" do
      sign_in admin_user
      other_org = create(:organization)
      other_project = create(:project, organization: other_org)
      get project_change_sets_path(other_project)
      expect(response).to have_http_status(:not_found)
    end

    it "allows viewer access" do
      sign_in viewer_user
      get project_change_sets_path(project)
      expect(response).to have_http_status(:success)
    end
  end

  # ─── NEW ───────────────────────────────────────────────────────

  describe "GET /projects/:project_id/change_sets/new" do
    it "renders the new form" do
      sign_in admin_user
      get new_project_change_set_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("New Change Set")
    end

    it "shows reviewer selection" do
      sign_in admin_user
      get new_project_change_set_path(project)
      expect(response.body).to include(pm_user.full_name)
      expect(response.body).to include(reviewer_user.full_name)
    end

    it "denies viewer access" do
      sign_in viewer_user
      get new_project_change_set_path(project)
      expect(response).to redirect_to(root_path)
    end

    it "denies reviewer access" do
      sign_in reviewer_user
      get new_project_change_set_path(project)
      expect(response).to redirect_to(root_path)
    end
  end

  # ─── CREATE ────────────────────────────────────────────────────

  describe "POST /projects/:project_id/change_sets" do
    it "creates a change set with valid params" do
      sign_in admin_user
      expect {
        post project_change_sets_path(project), params: {
          change_set: { title: "Update safety reqs", description: "Updating ASIL-D requirements" }
        }
      }.to change(ChangeSet, :count).by(1)

      cs = ChangeSet.last
      expect(cs.title).to eq("Update safety reqs")
      expect(cs.description).to eq("Updating ASIL-D requirements")
      expect(cs.created_by).to eq(admin_user)
      expect(cs.project).to eq(project)
      expect(cs.draft?).to be true
      expect(response).to redirect_to(project_change_set_path(project, cs))
    end

    it "adds selected reviewers as pending approvals" do
      sign_in admin_user
      post project_change_sets_path(project), params: {
        change_set: { title: "With reviewers", reviewer_ids: [ reviewer_user.id, pm_user.id ] }
      }

      cs = ChangeSet.last
      expect(cs.change_set_approvals.count).to eq(2)
      expect(cs.change_set_approvals.pluck(:user_id)).to contain_exactly(reviewer_user.id, pm_user.id)
      expect(cs.change_set_approvals.all?(&:pending?)).to be true
    end

    it "rejects blank title" do
      sign_in admin_user
      post project_change_sets_path(project), params: {
        change_set: { title: "", description: "No title" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "creates a PaperTrail version" do
      sign_in admin_user
      post project_change_sets_path(project), params: {
        change_set: { title: "Tracked change set" }
      }
      cs = ChangeSet.last
      expect(cs.versions.count).to eq(1)
    end

    it "denies viewer access" do
      sign_in viewer_user
      post project_change_sets_path(project), params: {
        change_set: { title: "Should fail" }
      }
      expect(response).to redirect_to(root_path)
    end

    it "allows author access" do
      sign_in author_user
      expect {
        post project_change_sets_path(project), params: {
          change_set: { title: "Author CS" }
        }
      }.to change(ChangeSet, :count).by(1)
    end

    it "denies reviewer access" do
      sign_in reviewer_user
      post project_change_sets_path(project), params: {
        change_set: { title: "Should fail" }
      }
      expect(response).to redirect_to(root_path)
    end
  end

  # ─── SHOW ──────────────────────────────────────────────────────

  describe "GET /projects/:project_id/change_sets/:id" do
    it "renders the show page" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      get project_change_set_path(project, cs)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(cs.title)
    end

    it "shows breadcrumbs" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      get project_change_set_path(project, cs)
      expect(response.body).to include("Change Sets")
      expect(response.body).to include(cs.title)
    end

    it "shows change set description" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user, description: "Important changes")
      get project_change_set_path(project, cs)
      expect(response.body).to include("Important changes")
    end

    it "shows status badge" do
      sign_in admin_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      get project_change_set_path(project, cs)
      expect(response.body).to include("In review")
    end

    it "shows stats row" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      create_change_with_requirement(cs, change_type: :created)
      get project_change_set_path(project, cs)
      expect(response.body).to include("Changes")
      expect(response.body).to include("Approvals")
      expect(response.body).to include("Review Progress")
    end

    it "shows changes grouped by type" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      create_change_with_requirement(cs, change_type: :created)
      create_change_with_requirement(cs, change_type: :modified)
      get project_change_set_path(project, cs)
      expect(response.body).to include("Added")
      expect(response.body).to include("Modified")
    end

    it "shows empty state when no changes" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      get project_change_set_path(project, cs)
      expect(response.body).to include("No changes yet")
    end

    it "shows reviewer approvals" do
      sign_in admin_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      create(:change_set_approval, :approved, change_set: cs, user: reviewer_user)
      get project_change_set_path(project, cs)
      expect(response.body).to include(reviewer_user.full_name)
      expect(response.body).to include("Approved")
    end

    it "shows workflow transition buttons" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      get project_change_set_path(project, cs)
      expect(response.body).to include("Submit for Review")
    end

    it "shows merge banner for approved change sets" do
      sign_in admin_user
      cs = create(:change_set, :approved, project: project, created_by: admin_user)
      create(:change_set_approval, :approved, change_set: cs, user: reviewer_user)
      get project_change_set_path(project, cs)
      expect(response.body).to include("Ready to merge")
      expect(response.body).to include("Merge Change Set")
    end

    it "shows merged banner for merged change sets" do
      sign_in admin_user
      cs = create(:change_set, :merged, project: project, created_by: admin_user, merge_commit_message: "Applied all changes")
      get project_change_set_path(project, cs)
      expect(response.body).to include("Merged")
      expect(response.body).to include("Applied all changes")
    end

    it "shows merge rules when configured" do
      sign_in admin_user
      create(:change_set_rule, project: project, min_approvals: 2)
      cs = create(:change_set, project: project, created_by: admin_user)
      get project_change_set_path(project, cs)
      expect(response.body).to include("Merge Rules")
      expect(response.body).to include("2")
    end

    it "shows diff for modified changes" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      change = create_change_with_requirement(cs, change_type: :modified)
      get project_change_set_path(project, cs)
      expect(response.body).to include("Modified")
      expect(response.body).to include(change.requirement.uid)
    end

    it "shows approval actions for reviewers on in_review change sets" do
      sign_in reviewer_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      get project_change_set_path(project, cs)
      expect(response.body).to include("Your Review")
      expect(response.body).to include("Approve")
      expect(response.body).to include("Request Changes")
    end

    it "hides approval actions for the creator" do
      sign_in admin_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      get project_change_set_path(project, cs)
      expect(response.body).not_to include("Your Review")
    end

    it "returns 404 for cross-org projects" do
      sign_in admin_user
      other_org = create(:organization)
      other_project = create(:project, organization: other_org)
      other_cs = create(:change_set, project: other_project, created_by: create(:user))
      get project_change_set_path(other_project, other_cs)
      expect(response).to have_http_status(:not_found)
    end

    it "allows viewer access" do
      sign_in viewer_user
      cs = create(:change_set, project: project, created_by: admin_user)
      get project_change_set_path(project, cs)
      expect(response).to have_http_status(:success)
    end
  end

  # ─── EDIT ──────────────────────────────────────────────────────

  describe "GET /projects/:project_id/change_sets/:id/edit" do
    it "renders the edit form for draft change sets" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      get edit_project_change_set_path(project, cs)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Edit Change Set")
    end

    it "allows the creator to edit" do
      sign_in author_user
      cs = create(:change_set, project: project, created_by: author_user)
      get edit_project_change_set_path(project, cs)
      expect(response).to have_http_status(:success)
    end

    it "allows PM to edit any change set" do
      sign_in pm_user
      cs = create(:change_set, project: project, created_by: author_user)
      get edit_project_change_set_path(project, cs)
      expect(response).to have_http_status(:success)
    end

    it "denies viewer access" do
      sign_in viewer_user
      cs = create(:change_set, project: project, created_by: admin_user)
      get edit_project_change_set_path(project, cs)
      expect(response).to redirect_to(root_path)
    end

    it "denies reviewer access (not creator)" do
      sign_in reviewer_user
      cs = create(:change_set, project: project, created_by: admin_user)
      get edit_project_change_set_path(project, cs)
      expect(response).to redirect_to(root_path)
    end
  end

  # ─── UPDATE ────────────────────────────────────────────────────

  describe "PATCH /projects/:project_id/change_sets/:id" do
    it "updates title and description" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      patch project_change_set_path(project, cs), params: {
        change_set: { title: "Updated Title", description: "Updated desc" }
      }
      expect(response).to redirect_to(project_change_set_path(project, cs))
      cs.reload
      expect(cs.title).to eq("Updated Title")
      expect(cs.description).to eq("Updated desc")
    end

    it "rejects blank title" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      patch project_change_set_path(project, cs), params: {
        change_set: { title: "" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "denies viewer access" do
      sign_in viewer_user
      cs = create(:change_set, project: project, created_by: admin_user)
      patch project_change_set_path(project, cs), params: {
        change_set: { title: "Should fail" }
      }
      expect(response).to redirect_to(root_path)
    end
  end

  # ─── DESTROY ───────────────────────────────────────────────────

  describe "DELETE /projects/:project_id/change_sets/:id" do
    it "deletes the change set" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      expect {
        delete project_change_set_path(project, cs)
      }.to change(ChangeSet, :count).by(-1)
      expect(response).to redirect_to(project_change_sets_path(project))
    end

    it "allows PM to delete" do
      sign_in pm_user
      cs = create(:change_set, project: project, created_by: admin_user)
      delete project_change_set_path(project, cs)
      expect(response).to redirect_to(project_change_sets_path(project))
    end

    it "denies author access" do
      sign_in author_user
      cs = create(:change_set, project: project, created_by: author_user)
      delete project_change_set_path(project, cs)
      expect(response).to redirect_to(root_path)
    end

    it "denies viewer access" do
      sign_in viewer_user
      cs = create(:change_set, project: project, created_by: admin_user)
      delete project_change_set_path(project, cs)
      expect(response).to redirect_to(root_path)
    end
  end

  # ─── TRANSITION STATUS ─────────────────────────────────────────

  describe "PATCH /projects/:project_id/change_sets/:id/transition_status" do
    it "transitions draft to open" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      patch transition_status_project_change_set_path(project, cs), params: { status: "open" }
      expect(response).to redirect_to(project_change_set_path(project, cs))
      expect(cs.reload.open?).to be true
    end

    it "transitions open to in_review" do
      sign_in admin_user
      cs = create(:change_set, :open, project: project, created_by: admin_user)
      patch transition_status_project_change_set_path(project, cs), params: { status: "in_review" }
      expect(cs.reload.in_review?).to be true
    end

    it "transitions in_review to approved" do
      sign_in admin_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      patch transition_status_project_change_set_path(project, cs), params: { status: "approved" }
      expect(cs.reload.approved?).to be true
    end

    it "rejects invalid transitions" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      patch transition_status_project_change_set_path(project, cs), params: { status: "merged" }
      expect(response).to redirect_to(project_change_set_path(project, cs))
      expect(flash[:alert]).to be_present
      expect(cs.reload.draft?).to be true
    end

    it "allows closing from any state" do
      sign_in admin_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      patch transition_status_project_change_set_path(project, cs), params: { status: "closed" }
      expect(cs.reload.closed?).to be true
    end

    it "allows reopening closed as draft" do
      sign_in admin_user
      cs = create(:change_set, :closed, project: project, created_by: admin_user)
      patch transition_status_project_change_set_path(project, cs), params: { status: "draft" }
      expect(cs.reload.draft?).to be true
    end

    it "tracks transitions with PaperTrail" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      expect {
        patch transition_status_project_change_set_path(project, cs), params: { status: "open" }
      }.to change { cs.versions.count }.by(1)
    end

    it "denies viewer access" do
      sign_in viewer_user
      cs = create(:change_set, project: project, created_by: admin_user)
      patch transition_status_project_change_set_path(project, cs), params: { status: "open" }
      expect(response).to redirect_to(root_path)
    end

    it "allows creator to transition" do
      sign_in author_user
      cs = create(:change_set, project: project, created_by: author_user)
      patch transition_status_project_change_set_path(project, cs), params: { status: "open" }
      expect(cs.reload.open?).to be true
    end

    it "walks through the full happy path" do
      sign_in admin_user
      cs = create(:change_set, project: project, created_by: admin_user)
      # draft -> open
      patch transition_status_project_change_set_path(project, cs), params: { status: "open" }
      expect(cs.reload.open?).to be true
      # open -> in_review
      patch transition_status_project_change_set_path(project, cs), params: { status: "in_review" }
      expect(cs.reload.in_review?).to be true
      # in_review -> approved
      patch transition_status_project_change_set_path(project, cs), params: { status: "approved" }
      expect(cs.reload.approved?).to be true
    end
  end

  # ─── APPROVE ───────────────────────────────────────────────────

  describe "POST /projects/:project_id/change_sets/:id/approve" do
    it "creates an approval" do
      sign_in reviewer_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      post approve_project_change_set_path(project, cs), params: { approval_status: "approved" }
      expect(response).to redirect_to(project_change_set_path(project, cs))
      expect(cs.change_set_approvals.where(user: reviewer_user, status: :approved)).to exist
    end

    it "records approval with body" do
      sign_in reviewer_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      post approve_project_change_set_path(project, cs), params: { approval_status: "approved", body: "LGTM" }
      approval = cs.change_set_approvals.find_by(user: reviewer_user)
      expect(approval.body).to eq("LGTM")
    end

    it "updates existing approval" do
      sign_in reviewer_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      create(:change_set_approval, change_set: cs, user: reviewer_user, status: :pending)
      post approve_project_change_set_path(project, cs), params: { approval_status: "approved" }
      expect(cs.change_set_approvals.find_by(user: reviewer_user).approved?).to be true
    end

    it "allows commenting without approving" do
      sign_in reviewer_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      post approve_project_change_set_path(project, cs), params: { approval_status: "commented", body: "Just a note" }
      approval = cs.change_set_approvals.find_by(user: reviewer_user)
      expect(approval.commented?).to be true
    end

    it "denies creator from approving own change set" do
      sign_in admin_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      post approve_project_change_set_path(project, cs), params: { approval_status: "approved" }
      expect(response).to redirect_to(root_path)
    end

    it "denies viewer access" do
      sign_in viewer_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      post approve_project_change_set_path(project, cs), params: { approval_status: "approved" }
      expect(response).to redirect_to(root_path)
    end

    it "allows PM to approve (if not creator)" do
      sign_in pm_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      post approve_project_change_set_path(project, cs), params: { approval_status: "approved" }
      expect(cs.change_set_approvals.where(user: pm_user, status: :approved)).to exist
    end

    it "allows author to approve (if not creator)" do
      sign_in author_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      post approve_project_change_set_path(project, cs), params: { approval_status: "approved" }
      expect(cs.change_set_approvals.where(user: author_user, status: :approved)).to exist
    end
  end

  # ─── REQUEST CHANGES ───────────────────────────────────────────

  describe "POST /projects/:project_id/change_sets/:id/request_changes" do
    it "creates a changes_requested approval" do
      sign_in reviewer_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      post request_changes_project_change_set_path(project, cs), params: { body: "Fix the safety reqs" }
      expect(response).to redirect_to(project_change_set_path(project, cs))
      approval = cs.change_set_approvals.find_by(user: reviewer_user)
      expect(approval.changes_requested?).to be true
      expect(approval.body).to eq("Fix the safety reqs")
    end

    it "denies creator from requesting changes on own change set" do
      sign_in admin_user
      cs = create(:change_set, :in_review, project: project, created_by: admin_user)
      post request_changes_project_change_set_path(project, cs)
      expect(response).to redirect_to(root_path)
    end
  end

  # ─── MERGE ─────────────────────────────────────────────────────

  describe "POST /projects/:project_id/change_sets/:id/merge" do
    it "merges an approved change set" do
      sign_in admin_user
      cs = create(:change_set, :approved, project: project, created_by: author_user)
      mod = create(:requirement_module, project: project)
      section = create(:section, requirement_module: mod)
      req = create(:requirement, project: project, section: section, created_by: admin_user, title: "Old Title")
      create(:change_set_change, change_set: cs, requirement: req, change_type: :modified,
        before_snapshot: { "title" => "Old Title" },
        after_snapshot: { "title" => "New Title" })

      post merge_project_change_set_path(project, cs), params: { merge_commit_message: "Applied safety updates" }

      expect(response).to redirect_to(project_change_set_path(project, cs))
      cs.reload
      expect(cs.merged?).to be true
      expect(cs.merged_by).to eq(admin_user)
      expect(cs.merged_at).to be_present
      expect(cs.merge_commit_message).to eq("Applied safety updates")
      expect(req.reload.title).to eq("New Title")
    end

    it "rejects merge of non-approved change set" do
      sign_in admin_user
      cs = create(:change_set, :in_review, project: project, created_by: author_user)
      post merge_project_change_set_path(project, cs)
      expect(response).to redirect_to(project_change_set_path(project, cs))
      expect(flash[:alert]).to include("approved")
      expect(cs.reload.in_review?).to be true
    end

    it "allows PM to merge" do
      sign_in pm_user
      cs = create(:change_set, :approved, project: project, created_by: author_user)
      post merge_project_change_set_path(project, cs)
      expect(cs.reload.merged?).to be true
    end

    it "denies author from merging" do
      sign_in author_user
      cs = create(:change_set, :approved, project: project, created_by: author_user)
      post merge_project_change_set_path(project, cs)
      expect(response).to redirect_to(root_path)
    end

    it "denies reviewer from merging" do
      sign_in reviewer_user
      cs = create(:change_set, :approved, project: project, created_by: admin_user)
      post merge_project_change_set_path(project, cs)
      expect(response).to redirect_to(root_path)
    end

    it "denies viewer from merging" do
      sign_in viewer_user
      cs = create(:change_set, :approved, project: project, created_by: admin_user)
      post merge_project_change_set_path(project, cs)
      expect(response).to redirect_to(root_path)
    end
  end
end
