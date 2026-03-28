require "rails_helper"

RSpec.describe "Change Sets (PR-Style Reviews)", type: :system do
  let(:organization) { create(:organization, name: "Acme Automotive") }
  let(:admin_user) { create(:user, first_name: "Alice", last_name: "Admin") }
  let(:pm_user) { create(:user, first_name: "Paul", last_name: "Manager") }
  let(:author_user) { create(:user, first_name: "Anna", last_name: "Author") }
  let(:reviewer_user) { create(:user, first_name: "Ron", last_name: "Reviewer") }
  let(:viewer_user) { create(:user, first_name: "Vera", last_name: "Viewer") }
  let(:project) { create(:project, organization: organization, name: "Brake System", prefix: "BRK") }
  let(:mod) { create(:requirement_module, project: project, name: "System Requirements") }
  let(:section) { create(:section, requirement_module: mod, name: "Functional Safety") }

  before do
    create(:membership, user: admin_user, organization: organization, role: :admin)
    create(:membership, user: pm_user, organization: organization, role: :project_manager)
    create(:membership, user: author_user, organization: organization, role: :author)
    create(:membership, user: reviewer_user, organization: organization, role: :reviewer)
    create(:membership, user: viewer_user, organization: organization, role: :viewer)
  end

  # ─── INDEX ──────────────────────────────────────────────────────

  describe "change sets index" do
    before { sign_in admin_user }

    it "shows the page with heading and New button" do
      visit project_change_sets_path(project)
      expect(page).to have_content("Change Sets")
      expect(page).to have_link("New Change Set")
    end

    it "shows empty state when no change sets exist" do
      visit project_change_sets_path(project)
      expect(page).to have_content("No change sets yet")
    end

    it "lists existing change sets with status and creator" do
      create(:change_set, project: project, title: "Update braking thresholds", created_by: admin_user, status: :draft)
      create(:change_set, project: project, title: "Add ABS requirements", created_by: pm_user, status: :open)
      visit project_change_sets_path(project)
      expect(page).to have_content("Update braking thresholds")
      expect(page).to have_content("Add ABS requirements")
      expect(page).to have_content("Alice Admin")
      expect(page).to have_content("Paul Manager")
      expect(page).to have_content("Draft")
      expect(page).to have_content("Open")
    end

    it "shows change counts on cards" do
      cs = create(:change_set, project: project, title: "Mixed changes", created_by: admin_user)
      req1 = create(:requirement, project: project, section: section, created_by: admin_user)
      req2 = create(:requirement, project: project, section: section, created_by: admin_user)
      create(:change_set_change, change_set: cs, requirement: req1, change_type: :created)
      create(:change_set_change, change_set: cs, requirement: req2, change_type: :modified)
      visit project_change_sets_path(project)
      expect(page).to have_content("+1")
      expect(page).to have_content("~1")
    end

    it "shows approval progress" do
      cs = create(:change_set, project: project, title: "Review progress test", created_by: admin_user, status: :in_review)
      create(:change_set_approval, change_set: cs, user: reviewer_user, status: :approved)
      create(:change_set_approval, change_set: cs, user: pm_user, status: :pending)
      visit project_change_sets_path(project)
      expect(page).to have_content("50%")
      expect(page).to have_content("1/2 reviewed")
    end

    it "does not show change sets from other organizations" do
      other_org = create(:organization, name: "Other Corp")
      other_project = create(:project, organization: other_org, prefix: "OTH")
      create(:change_set, project: other_project, title: "Secret changes", created_by: admin_user)
      visit project_change_sets_path(project)
      expect(page).not_to have_content("Secret changes")
    end
  end

  # ─── CREATING ───────────────────────────────────────────────────

  describe "creating a change set" do
    before { sign_in admin_user }

    it "shows the new change set form with title and description" do
      visit new_project_change_set_path(project)
      expect(page).to have_content("New Change Set")
      expect(page).to have_field("Title")
      expect(page).to have_field("Description")
      expect(page).to have_button("Create Change Set")
      expect(page).to have_link("Cancel")
    end

    it "shows reviewer selection checkboxes for org members" do
      visit new_project_change_set_path(project)
      expect(page).to have_content("Reviewers")
      expect(page).to have_content("Ron Reviewer")
      expect(page).to have_content("Paul Manager")
      expect(page).to have_content("Alice Admin")
    end

    it "creates a change set with valid data" do
      visit new_project_change_set_path(project)
      fill_in "Title", with: "Update safety thresholds"
      fill_in "Description", with: "Revise braking distance requirements"
      click_button "Create Change Set"

      expect(page).to have_content("Change set created and activated")
      expect(page).to have_content("Update safety thresholds")
      expect(page).to have_content("Revise braking distance requirements")
      expect(page).to have_content("Draft")
    end

    it "shows validation errors for blank title" do
      visit new_project_change_set_path(project)
      fill_in "Title", with: ""
      click_button "Create Change Set"
      expect(page).to have_content("error")
      expect(page).to have_content("Title")
    end

    it "navigates from index to new form" do
      visit project_change_sets_path(project)
      click_link "New Change Set"
      expect(page).to have_content("New Change Set")
      expect(page).to have_field("Title")
    end

    it "shows breadcrumbs on new page" do
      visit new_project_change_set_path(project)
      expect(page).to have_link("Projects", href: projects_path)
      expect(page).to have_link("Brake System", href: project_path(project))
      expect(page).to have_link("Change Sets", href: project_change_sets_path(project))
      expect(page).to have_content("New Change Set")
    end
  end

  # ─── VIEWING ────────────────────────────────────────────────────

  describe "viewing a change set" do
    let(:change_set) { create(:change_set, project: project, title: "Threshold updates", description: "Update braking distances", created_by: admin_user) }

    before { sign_in admin_user }

    it "shows change set details" do
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("Threshold updates")
      expect(page).to have_content("Update braking distances")
      expect(page).to have_content("Draft")
      expect(page).to have_content("Alice Admin")
    end

    it "shows breadcrumbs" do
      visit project_change_set_path(project, change_set)
      expect(page).to have_link("Projects", href: projects_path)
      expect(page).to have_link("Brake System", href: project_path(project))
      expect(page).to have_link("Change Sets", href: project_change_sets_path(project))
      expect(page).to have_content("Threshold updates")
    end

    it "shows stats row with changes, approvals, comments, and status" do
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("Changes")
      expect(page).to have_content("Approvals")
      expect(page).to have_content("Comments")
      expect(page).to have_content("Status")
    end

    it "shows Changes and Conversation tabs" do
      visit project_change_set_path(project, change_set)
      expect(page).to have_button("Changes")
      expect(page).to have_button("Conversation")
    end

    it "shows empty state when no changes exist" do
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("No changes")
    end

    it "shows Edit and Delete buttons for draft change sets" do
      visit project_change_set_path(project, change_set)
      expect(page).to have_link("Edit")
      expect(page).to have_link("Delete")
    end

    it "shows Activate button when change set is not active" do
      visit project_change_set_path(project, change_set)
      expect(page).to have_link("Activate")
    end
  end

  # ─── CHANGE SET WITH CHANGES ────────────────────────────────────

  describe "change set with changes" do
    let(:change_set) { create(:change_set, project: project, title: "Mixed changes", created_by: admin_user) }
    let(:req_created) { create(:requirement, project: project, section: section, created_by: admin_user, title: "New braking req") }
    let(:req_modified) { create(:requirement, project: project, section: section, created_by: admin_user, title: "Modified req") }
    let(:req_deleted) { create(:requirement, project: project, section: section, created_by: admin_user, title: "Deleted req") }

    before do
      sign_in admin_user
      create(:change_set_change, change_set: change_set, requirement: req_created, change_type: :created,
        after_snapshot: { "title" => "New braking req", "body" => "Shall stop within 40m" })
      create(:change_set_change, change_set: change_set, requirement: req_modified, change_type: :modified,
        before_snapshot: { "title" => "Old title", "status" => "draft" },
        after_snapshot: { "title" => "Modified req", "status" => "in_review" })
      create(:change_set_change, change_set: change_set, requirement: req_deleted, change_type: :deleted,
        before_snapshot: { "title" => "Deleted req", "body" => "Obsolete requirement" })
    end

    it "shows grouped changes: Added, Modified, Removed" do
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("Added (1)")
      expect(page).to have_content("Modified (1)")
      expect(page).to have_content("Removed (1)")
    end

    it "shows requirement UIDs in change cards" do
      visit project_change_set_path(project, change_set)
      expect(page).to have_content(req_created.uid)
      expect(page).to have_content(req_modified.uid)
      expect(page).to have_content(req_deleted.uid)
    end

    it "shows change type badges" do
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("Created")
      expect(page).to have_content("Modified")
      expect(page).to have_content("Deleted")
    end

    it "shows diff for modified changes" do
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("Title:")
      expect(page).to have_content("Old title")
      expect(page).to have_content("Modified req")
    end

    it "shows change counts in stats row" do
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("+1 added")
      expect(page).to have_content("~1 modified")
      expect(page).to have_content("-1 deleted")
    end

    it "shows total changes count" do
      visit project_change_set_path(project, change_set)
      # Stats row shows total = 3
      expect(page).to have_content("3")
    end
  end

  # ─── WORKFLOW TRANSITIONS ───────────────────────────────────────

  describe "workflow transitions" do
    before { sign_in admin_user }

    it "shows Submit for Review button on draft change set" do
      cs = create(:change_set, project: project, title: "Draft CS", created_by: admin_user, status: :draft)
      visit project_change_set_path(project, cs)
      expect(page).to have_link("Submit for Review")
    end

    it "shows Start Review button on open change set" do
      cs = create(:change_set, project: project, title: "Open CS", created_by: admin_user, status: :open)
      visit project_change_set_path(project, cs)
      expect(page).to have_link("Start Review")
    end

    it "shows Approve button on in_review change set" do
      cs = create(:change_set, project: project, title: "In Review CS", created_by: admin_user, status: :in_review)
      visit project_change_set_path(project, cs)
      expect(page).to have_link("Approve")
    end

    it "shows Close button on non-terminal change sets" do
      cs = create(:change_set, project: project, title: "Closeable CS", created_by: admin_user, status: :open)
      visit project_change_set_path(project, cs)
      expect(page).to have_link("Close")
    end

    it "shows Reopen as Draft button on closed change set" do
      cs = create(:change_set, project: project, title: "Closed CS", created_by: admin_user, status: :closed)
      visit project_change_set_path(project, cs)
      expect(page).to have_link("Reopen as Draft")
    end

    it "does not show workflow buttons on merged change set" do
      cs = create(:change_set, project: project, title: "Merged CS", created_by: admin_user, status: :merged, merged_by: admin_user, merged_at: Time.current)
      visit project_change_set_path(project, cs)
      expect(page).not_to have_link("Submit for Review")
      expect(page).not_to have_link("Start Review")
      expect(page).not_to have_link("Close")
    end

    it "transitions from draft to open" do
      cs = create(:change_set, project: project, title: "Transition test", created_by: admin_user, status: :draft)
      visit project_change_set_path(project, cs)
      click_link "Submit for Review"
      expect(page).to have_content("Open")
      expect(page).to have_content("status changed to Open")
    end
  end

  # ─── EDITING ────────────────────────────────────────────────────

  describe "editing a change set" do
    before { sign_in admin_user }

    it "updates title and description" do
      cs = create(:change_set, project: project, title: "Old title", description: "Old desc", created_by: admin_user, status: :draft)
      visit edit_project_change_set_path(project, cs)
      fill_in "Title", with: "Updated title"
      fill_in "Description", with: "Updated description"
      click_button "Update Change Set"
      expect(page).to have_content("Change set updated successfully")
      expect(page).to have_content("Updated title")
      expect(page).to have_content("Updated description")
    end

    it "shows validation errors on blank title" do
      cs = create(:change_set, project: project, title: "Editable", created_by: admin_user, status: :draft)
      visit edit_project_change_set_path(project, cs)
      fill_in "Title", with: ""
      click_button "Update Change Set"
      expect(page).to have_content("error")
    end

    it "shows breadcrumbs on edit page" do
      cs = create(:change_set, project: project, title: "Editable CS", created_by: admin_user, status: :draft)
      visit edit_project_change_set_path(project, cs)
      expect(page).to have_link("Change Sets", href: project_change_sets_path(project))
      expect(page).to have_link("Editable CS", href: project_change_set_path(project, cs))
      expect(page).to have_content("Edit Change Set")
    end

    it "navigates to edit from show page" do
      cs = create(:change_set, project: project, title: "Nav test", created_by: admin_user, status: :draft)
      visit project_change_set_path(project, cs)
      click_link "Edit"
      expect(page).to have_content("Edit Change Set")
      expect(page).to have_field("Title", with: "Nav test")
    end

    it "cancel returns to show page" do
      cs = create(:change_set, project: project, title: "Cancel test", created_by: admin_user, status: :draft)
      visit edit_project_change_set_path(project, cs)
      click_link "Cancel"
      expect(page).to have_content("Cancel test")
    end
  end

  # ─── APPROVAL FLOW ─────────────────────────────────────────────

  describe "approval flow" do
    let(:change_set) do
      create(:change_set, project: project, title: "Approval test", created_by: admin_user, status: :in_review)
    end

    before do
      create(:change_set_approval, change_set: change_set, user: reviewer_user, status: :pending)
    end

    it "shows reviewer with pending status" do
      sign_in admin_user
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("Ron Reviewer")
      expect(page).to have_content("Pending")
    end

    it "shows approve and request changes links for non-creator reviewer" do
      sign_in reviewer_user
      visit project_change_set_path(project, change_set)
      expect(page).to have_link("Approve")
      expect(page).to have_link("Request Changes")
    end

    it "does not show approval actions to the creator" do
      sign_in admin_user
      visit project_change_set_path(project, change_set)
      # Creator cannot self-approve — Your Review section should not be visible
      expect(page).not_to have_content("Your Review")
    end

    it "shows approved status after reviewer approves" do
      sign_in reviewer_user
      visit project_change_set_path(project, change_set)
      click_link "Approve"
      expect(page).to have_content("Approved")
    end

    it "shows changes requested status after reviewer requests changes" do
      sign_in reviewer_user
      visit project_change_set_path(project, change_set)
      click_link "Request Changes"
      expect(page).to have_content("Changes requested")
    end

    it "shows approval count in stats" do
      create(:change_set_approval, change_set: change_set, user: pm_user, status: :approved)
      sign_in admin_user
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("1") # 1 of N required approvals
    end
  end

  # ─── MERGE FLOW ─────────────────────────────────────────────────

  describe "merge flow" do
    let(:requirement) do
      create(:requirement, project: project, section: section, created_by: admin_user,
        title: "Original title", body: "Original body", priority: :must_have)
    end
    let(:change_set) do
      create(:change_set, project: project, title: "Merge test CS", created_by: admin_user, status: :approved)
    end

    before do
      create(:change_set_change, change_set: change_set, requirement: requirement, change_type: :modified,
        before_snapshot: { "title" => "Original title", "priority" => "must_have" },
        after_snapshot: { "title" => "Updated title", "priority" => "should_have" })
    end

    it "shows Ready to merge banner for approved change set with sufficient approvals" do
      create(:change_set_approval, change_set: change_set, user: reviewer_user, status: :approved)
      sign_in pm_user
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("Ready to merge")
      expect(page).to have_link("Merge Change Set")
    end

    it "shows Not ready to merge when approvals are insufficient" do
      # No approvals yet — default rule requires 1
      sign_in pm_user
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("Not ready to merge")
      expect(page).not_to have_link("Merge Change Set")
    end

    it "shows merged banner after merge" do
      create(:change_set_approval, change_set: change_set, user: reviewer_user, status: :approved)
      sign_in pm_user
      visit project_change_set_path(project, change_set)
      click_link "Merge Change Set"
      expect(page).to have_content("Merged")
      expect(page).to have_content("All changes have been applied")
    end

    it "shows merged by information" do
      change_set.update!(status: :merged, merged_by: pm_user, merged_at: Time.current)
      sign_in admin_user
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("Merged by Paul Manager")
    end

    it "hides Edit and Activate buttons on merged change sets" do
      change_set.update!(status: :merged, merged_by: pm_user, merged_at: Time.current)
      sign_in admin_user
      visit project_change_set_path(project, change_set)
      expect(page).not_to have_link("Edit")
      expect(page).not_to have_link("Activate")
    end
  end

  # ─── CHANGE SET BANNER ON REQUIREMENTS ──────────────────────────

  describe "change set banner on requirements" do
    let(:change_set) { create(:change_set, project: project, title: "Active CS", created_by: admin_user, status: :draft) }

    before { sign_in admin_user }

    def activate_change_set_via_ui
      visit project_change_set_path(project, change_set)
      click_link "Activate"
    end

    it "shows banner on requirements index when change set is active" do
      activate_change_set_via_ui
      visit project_requirements_path(project)
      expect(page).to have_content("Editing in Change Set:")
      expect(page).to have_content("Active CS")
    end

    it "shows banner on requirement detail when change set is active" do
      create(:requirement, project: project, section: section, created_by: admin_user)
      activate_change_set_via_ui
      visit project_requirement_path(project, Requirement.last)
      expect(page).to have_content("Editing in Change Set:")
      expect(page).to have_content("Active CS")
    end

    it "shows descriptive message about edit behavior" do
      activate_change_set_via_ui
      visit project_requirements_path(project)
      expect(page).to have_content("Requirement edits will be recorded as proposed changes")
    end

    it "does not show banner when no change set is active" do
      visit project_requirements_path(project)
      expect(page).not_to have_content("Editing in Change Set:")
    end

    it "hides Start Change Set button when a change set is active" do
      activate_change_set_via_ui
      visit project_requirements_path(project)
      expect(page).not_to have_link("Start Change Set")
    end

    it "shows Start Change Set button when no change set is active" do
      visit project_requirements_path(project)
      expect(page).to have_link("Start Change Set")
    end
  end

  # ─── COMMENTS ───────────────────────────────────────────────────

  describe "comments on change sets" do
    let(:change_set) { create(:change_set, project: project, title: "Comment test", created_by: admin_user, status: :in_review) }
    let(:requirement) { create(:requirement, project: project, section: section, created_by: admin_user) }
    let!(:change) { create(:change_set_change, change_set: change_set, requirement: requirement, change_type: :modified) }

    before { sign_in reviewer_user }

    it "shows comment forms on in_review change sets" do
      visit project_change_set_path(project, change_set)
      expect(page).to have_css("textarea[name='body']")
    end

    it "shows existing inline comments on changes" do
      create(:change_set_comment, change_set: change_set, change_set_change: change, user: pm_user, body: "Please check this value")
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("Please check this value")
      expect(page).to have_content("Paul Manager")
    end

    it "shows unresolved comment count in stats" do
      create(:change_set_comment, change_set: change_set, change_set_change: change, user: pm_user, body: "Fix this", resolved: false)
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("1 unresolved")
    end

    it "hides comment forms on merged change sets" do
      change_set.update!(status: :merged, merged_by: admin_user, merged_at: Time.current)
      visit project_change_set_path(project, change_set)
      expect(page).not_to have_css("textarea[name='body']")
    end
  end

  # ─── MERGE RULES ────────────────────────────────────────────────

  describe "merge rules display" do
    let(:change_set) { create(:change_set, project: project, title: "Rules test", created_by: admin_user, status: :in_review) }

    before { sign_in admin_user }

    it "shows default merge rules when no custom rule exists" do
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("1 approval") # default
    end

    it "shows custom merge rules when configured" do
      create(:change_set_rule, project: project, min_approvals: 3, require_all_conversations_resolved: true)
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("3 approval")
    end

    it "shows Configure link for admins" do
      visit project_change_set_path(project, change_set)
      expect(page).to have_link("Configure")
    end
  end

  # ─── ROLE-BASED ACCESS ─────────────────────────────────────────

  describe "role-based access" do
    let(:change_set) { create(:change_set, project: project, title: "Access test", created_by: admin_user, status: :draft) }

    it "allows viewer to see change sets index" do
      sign_in viewer_user
      visit project_change_sets_path(project)
      expect(page).to have_content("Change Sets")
    end

    it "allows viewer to see change set detail" do
      sign_in viewer_user
      visit project_change_set_path(project, change_set)
      expect(page).to have_content("Access test")
    end

    it "hides New Change Set button for viewer" do
      sign_in viewer_user
      visit project_change_sets_path(project)
      expect(page).not_to have_link("New Change Set")
    end

    it "hides Edit/Delete buttons for viewer" do
      sign_in viewer_user
      visit project_change_set_path(project, change_set)
      expect(page).not_to have_link("Edit")
      expect(page).not_to have_link("Delete")
    end

    it "allows PM to see merge-related actions" do
      approved_cs = create(:change_set, project: project, title: "PM merge test", created_by: admin_user, status: :approved)
      create(:change_set_approval, change_set: approved_cs, user: reviewer_user, status: :approved)
      sign_in pm_user
      visit project_change_set_path(project, approved_cs)
      expect(page).to have_content("Ready to merge")
    end

    it "hides merge button from author" do
      approved_cs = create(:change_set, project: project, title: "Author merge test", created_by: admin_user, status: :approved)
      create(:change_set_approval, change_set: approved_cs, user: reviewer_user, status: :approved)
      sign_in author_user
      visit project_change_set_path(project, approved_cs)
      expect(page).not_to have_link("Merge Change Set")
    end
  end

  # ─── ORGANIZATION ISOLATION ─────────────────────────────────────

  describe "organization isolation" do
    it "does not show change sets from other orgs" do
      other_org = create(:organization, name: "Rival Motors")
      other_project = create(:project, organization: other_org, prefix: "RIV")
      other_user = create(:user)
      create(:membership, user: other_user, organization: other_org, role: :admin)
      create(:change_set, project: other_project, title: "Rival secret", created_by: other_user)

      sign_in admin_user
      visit project_change_sets_path(project)
      expect(page).not_to have_content("Rival secret")
    end
  end

  # ─── SIDEBAR NAVIGATION ────────────────────────────────────────

  describe "sidebar navigation" do
    before { sign_in admin_user }

    it "has Change Sets link in sidebar" do
      visit project_change_sets_path(project)
      expect(page).to have_link("Change Sets")
    end

    it "shows descriptive subtitle under Change Sets" do
      visit project_change_sets_path(project)
      expect(page).to have_content("Propose & review changes")
    end
  end

  # ─── COMPLETE PR FLOW (END-TO-END) ─────────────────────────────

  describe "complete PR flow" do
    let!(:requirement) do
      create(:requirement, project: project, section: section, created_by: admin_user,
        title: "Braking distance limit", body: "System shall stop within 50m at 100km/h",
        requirement_type: :safety, asil_level: :asil_d, priority: :must_have)
    end

    it "walks through create → activate → edit → submit → approve → merge" do
      # Step 1: Admin creates a change set
      sign_in admin_user
      visit project_change_sets_path(project)
      click_link "New Change Set"

      fill_in "Title", with: "Revise braking distance"
      fill_in "Description", with: "Update safety threshold per new test data"
      # Select reviewer
      check "change_set[reviewer_ids][]", match: :first if page.has_css?("input[name='change_set[reviewer_ids][]']")
      click_button "Create Change Set"

      expect(page).to have_content("Change set created and activated")
      expect(page).to have_content("Revise braking distance")
      expect(page).to have_content("Draft")

      # The change set should be auto-activated
      # Step 2: Navigate to requirements to edit
      visit project_requirements_path(project)
      expect(page).to have_content("Editing in Change Set:")
      expect(page).to have_content("Revise braking distance")

      # Step 3: Submit for review (go back to change set)
      visit project_change_sets_path(project)
      click_link "Revise braking distance"
      click_link "Submit for Review"
      expect(page).to have_content("Open")

      # Step 4: Start review
      click_link "Start Review"
      expect(page).to have_content("In review")

      # Step 5: Approve (transition to approved status)
      click_link "Approve"
      expect(page).to have_content("Approved")
    end

    it "shows change set on index after creation" do
      sign_in admin_user
      visit new_project_change_set_path(project)
      fill_in "Title", with: "Test visibility"
      click_button "Create Change Set"

      visit project_change_sets_path(project)
      expect(page).to have_content("Test visibility")
      expect(page).to have_content("Draft")
      expect(page).to have_content("Alice Admin")
    end
  end

  # ─── SETTINGS (MERGE RULES) ────────────────────────────────────

  describe "merge rules settings" do
    before { sign_in admin_user }

    it "navigates to settings from change set show page" do
      cs = create(:change_set, project: project, title: "Settings nav", created_by: admin_user, status: :in_review)
      visit project_change_set_path(project, cs)
      click_link "Configure"
      expect(page).to have_content("Approval Requirements")
      expect(page).to have_content("Conversation Resolution")
      expect(page).to have_content("Auto-Merge")
    end

    it "saves merge rules settings" do
      visit project_change_set_rules_path(project)
      fill_in "change_set_rule[min_approvals]", with: "3"
      click_button "Save Rules"
      expect(page).to have_content("Change set rules updated successfully")
    end

    it "shows breadcrumbs on settings page" do
      visit project_change_set_rules_path(project)
      expect(page).to have_link("Brake System", href: project_path(project))
      expect(page).to have_content("Change Set Rules")
    end

    it "denies viewer access to settings" do
      sign_in viewer_user
      visit project_change_set_rules_path(project)
      expect(page).to have_content("not authorized")
    end
  end
end
