require "rails_helper"

RSpec.describe "My Work", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :author) }
  let!(:project) { create(:project, organization: organization, name: "Brake System") }
  let!(:mod) { create(:requirement_module, project: project, name: "System Req") }
  let!(:section) { create(:section, requirement_module: mod, name: "Safety") }

  before { sign_in user }

  describe "GET /my_work" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        get my_work_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it "renders the page" do
      get my_work_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("My Work")
    end

    it "shows breadcrumbs" do
      get my_work_path
      expect(response.body).to include("My Work")
    end

    it "shows subtitle" do
      get my_work_path
      expect(response.body).to include("Your requirements, change sets, reviews, and test cases across all projects")
    end

    # ===== Summary Cards =====

    it "shows summary stat cards" do
      get my_work_path
      expect(response.body).to include("My Requirements")
      expect(response.body).to include("Active Change Sets")
      expect(response.body).to include("Pending Reviews")
      expect(response.body).to include("My Test Cases")
    end

    it "shows correct requirements count in summary" do
      create(:requirement, section: section, project: project, created_by: user, title: "R1")
      create(:requirement, section: section, project: project, created_by: user, title: "R2")
      get my_work_path
      # @total_requirements = 2
      expect(response.body).to match(/>2<\/div>\s*<div[^>]*>.*My Requirements/m)
    end

    it "shows correct test cases count in summary" do
      create(:test_case, project: project, created_by: user)
      create(:test_case, project: project, created_by: user)
      create(:test_case, project: project, created_by: user)
      get my_work_path
      expect(response.body).to match(/>3<\/div>\s*<div[^>]*>.*My Test Cases/m)
    end

    # ===== My Requirements =====

    it "shows my requirements section" do
      get my_work_path
      expect(response.body).to include("My Requirements")
    end

    it "lists requirements authored by the current user" do
      req = create(:requirement, section: section, project: project, created_by: user, title: "Brake Force Req")
      get my_work_path
      expect(response.body).to include("Brake Force Req")
      expect(response.body).to include(req.uid)
    end

    it "does not list requirements authored by other users" do
      other = create(:user)
      create(:requirement, section: section, project: project, created_by: other, title: "Other User Req")
      get my_work_path
      expect(response.body).not_to include("Other User Req")
    end

    it "shows project name for each requirement" do
      create(:requirement, section: section, project: project, created_by: user, title: "Test Req")
      get my_work_path
      expect(response.body).to include("Brake System")
    end

    it "shows requirement status badge" do
      create(:requirement, section: section, project: project, created_by: user, title: "Approved Req", status: :approved)
      get my_work_path
      expect(response.body).to include("Approved")
    end

    it "shows requirement type badge" do
      create(:requirement, section: section, project: project, created_by: user, title: "Safety Req", requirement_type: :safety)
      get my_work_path
      expect(response.body).to include("Safety")
    end

    it "shows empty state when no requirements exist" do
      get my_work_path
      expect(response.body).to include("haven't authored any requirements yet")
    end

    it "shows total requirements count badge" do
      create(:requirement, section: section, project: project, created_by: user)
      create(:requirement, section: section, project: project, created_by: user)
      get my_work_path
      # Count badge next to "My Requirements" header
      expect(response.body).to include(">2<")
    end

    # ===== Status Filtering =====

    it "shows status filter pills" do
      create(:requirement, section: section, project: project, created_by: user, status: :draft)
      create(:requirement, section: section, project: project, created_by: user, status: :approved)
      get my_work_path
      expect(response.body).to include("All")
      expect(response.body).to include("Draft (1)")
      expect(response.body).to include("Approved (1)")
    end

    it "filters requirements by status" do
      create(:requirement, section: section, project: project, created_by: user, title: "Draft Req", status: :draft)
      create(:requirement, section: section, project: project, created_by: user, title: "Approved Req", status: :approved)
      get my_work_path(req_status: "draft")
      expect(response.body).to include("Draft Req")
      expect(response.body).not_to include("Approved Req")
    end

    it "shows filtered empty state for status with no results" do
      create(:requirement, section: section, project: project, created_by: user, status: :draft)
      get my_work_path(req_status: "approved")
      expect(response.body).to include("No requirements with status")
    end

    it "shows all requirements when filter is 'All'" do
      create(:requirement, section: section, project: project, created_by: user, title: "Draft Req", status: :draft)
      create(:requirement, section: section, project: project, created_by: user, title: "Approved Req", status: :approved)
      get my_work_path
      expect(response.body).to include("Draft Req")
      expect(response.body).to include("Approved Req")
    end

    it "ignores invalid status filter" do
      create(:requirement, section: section, project: project, created_by: user, title: "Draft Req", status: :draft)
      get my_work_path(req_status: "nonexistent")
      expect(response.body).to include("Draft Req")
    end

    # ===== Needs Your Review (Change Set Approvals) =====

    it "hides needs-your-review section when no pending reviews" do
      get my_work_path
      expect(response.body).not_to include("Needs Your Review")
    end

    it "shows needs-your-review section with pending change set approvals" do
      other_user = create(:user)
      create(:membership, user: other_user, organization: organization, role: :author)
      cs = create(:change_set, project: project, created_by: other_user, title: "Review This CS", status: :in_review)
      create(:change_set_approval, change_set: cs, user: user, status: :pending)
      get my_work_path
      expect(response.body).to include("Needs Your Review")
      expect(response.body).to include("Review This CS")
    end

    it "shows creator info in pending reviews" do
      other_user = create(:user, first_name: "Alice", last_name: "Author")
      create(:membership, user: other_user, organization: organization, role: :author)
      cs = create(:change_set, project: project, created_by: other_user, title: "Alice CS", status: :in_review)
      create(:change_set_approval, change_set: cs, user: user, status: :pending)
      get my_work_path
      expect(response.body).to include("Alice Author")
    end

    it "shows pending review count badge" do
      other_user = create(:user)
      create(:membership, user: other_user, organization: organization, role: :author)
      cs1 = create(:change_set, project: project, created_by: other_user, title: "CS 1", status: :in_review)
      cs2 = create(:change_set, project: project, created_by: other_user, title: "CS 2", status: :in_review)
      create(:change_set_approval, change_set: cs1, user: user, status: :pending)
      create(:change_set_approval, change_set: cs2, user: user, status: :pending)
      get my_work_path
      # Count badge should show 2
      expect(response.body).to include(">2<")
    end

    it "excludes already-decided approvals from pending reviews" do
      other_user = create(:user)
      create(:membership, user: other_user, organization: organization, role: :author)
      cs = create(:change_set, project: project, created_by: other_user, title: "Already Reviewed", status: :in_review)
      create(:change_set_approval, change_set: cs, user: user, status: :approved)
      get my_work_path
      expect(response.body).not_to include("Needs Your Review")
    end

    # ===== Active Formal Reviews =====

    it "hides formal reviews section when no active reviews" do
      get my_work_path
      expect(response.body).not_to include("Active Formal Reviews")
    end

    it "shows formal reviews where user is a participant" do
      review = create(:review, project: project, created_by: user, title: "Safety Review", status: :in_progress)
      create(:review_participant, review: review, user: user, role: :reviewer)
      get my_work_path
      expect(response.body).to include("Active Formal Reviews")
      expect(response.body).to include("Safety Review")
    end

    it "shows participant role in formal reviews" do
      review = create(:review, project: project, created_by: user, title: "Formal Rev", status: :open)
      create(:review_participant, review: review, user: user, role: :approver)
      get my_work_path
      # Role is rendered with CSS capitalize, so HTML text is lowercase
      expect(response.body).to include("approver")
    end

    it "excludes completed formal reviews" do
      review = create(:review, project: project, created_by: user, title: "Completed Rev", status: :completed)
      create(:review_participant, review: review, user: user, role: :reviewer)
      get my_work_path
      expect(response.body).not_to include("Active Formal Reviews")
    end

    # ===== My Change Sets =====

    it "shows my change sets section" do
      get my_work_path
      expect(response.body).to include("My Change Sets")
    end

    it "lists change sets created by the user" do
      cs = create(:change_set, project: project, created_by: user, title: "My Draft Changes", status: :draft)
      get my_work_path
      expect(response.body).to include("My Draft Changes")
    end

    it "shows change set status badge" do
      create(:change_set, project: project, created_by: user, title: "Open CS", status: :open)
      get my_work_path
      expect(response.body).to include("Open")
    end

    it "shows project name for change sets" do
      create(:change_set, project: project, created_by: user, title: "CS 1", status: :draft)
      get my_work_path
      expect(response.body).to include("Brake System")
    end

    it "excludes merged and closed change sets" do
      create(:change_set, project: project, created_by: user, title: "Merged CS", status: :merged)
      create(:change_set, project: project, created_by: user, title: "Closed CS", status: :closed)
      get my_work_path
      expect(response.body).not_to include("Merged CS")
      expect(response.body).not_to include("Closed CS")
    end

    it "shows change counts (added/modified/deleted)" do
      cs = create(:change_set, project: project, created_by: user, title: "With Changes", status: :draft)
      req = create(:requirement, section: section, project: project, created_by: user)
      create(:change_set_change, change_set: cs, requirement: req, change_type: :created)
      get my_work_path
      # Shows +1
      expect(response.body).to include("+1")
    end

    it "shows approval progress for change sets with approvals" do
      cs = create(:change_set, project: project, created_by: user, title: "In Review CS", status: :in_review)
      reviewer = create(:user)
      create(:membership, user: reviewer, organization: organization, role: :reviewer)
      create(:change_set_approval, change_set: cs, user: reviewer, status: :approved)
      get my_work_path
      expect(response.body).to include("1/1")
    end

    it "shows empty state when no active change sets" do
      get my_work_path
      expect(response.body).to include("No active change sets")
    end

    it "shows active change sets count badge" do
      create(:change_set, project: project, created_by: user, title: "CS 1", status: :draft)
      create(:change_set, project: project, created_by: user, title: "CS 2", status: :open)
      get my_work_path
      # Count badge next to "My Change Sets" header
      expect(response.body).to include(">2<")
    end

    # ===== My Test Cases =====

    it "shows my test cases section" do
      get my_work_path
      expect(response.body).to include("My Test Cases")
    end

    it "lists test cases created by the user" do
      tc = create(:test_case, project: project, created_by: user, title: "Brake Test", status: :not_run)
      get my_work_path
      expect(response.body).to include("Brake Test")
      expect(response.body).to include(tc.uid)
    end

    it "shows test case status badge" do
      create(:test_case, project: project, created_by: user, title: "Failed TC", status: :failed)
      get my_work_path
      expect(response.body).to include("Failed")
    end

    it "shows test case type badge" do
      create(:test_case, project: project, created_by: user, title: "System TC", test_type: :system)
      get my_work_path
      expect(response.body).to include("System")
    end

    it "shows linked requirement UID" do
      req = create(:requirement, section: section, project: project, created_by: user)
      tc = create(:test_case, project: project, created_by: user, requirement: req)
      get my_work_path
      expect(response.body).to include(req.uid)
    end

    it "shows dash for test cases without linked requirement" do
      create(:test_case, project: project, created_by: user, requirement: nil)
      get my_work_path
      expect(response.body).to include("&mdash;")
    end

    it "shows test case status distribution badges" do
      create(:test_case, project: project, created_by: user, status: :passed)
      create(:test_case, project: project, created_by: user, status: :failed)
      create(:test_case, project: project, created_by: user, status: :not_run)
      get my_work_path
      expect(response.body).to include("Passed (1)")
      expect(response.body).to include("Failed (1)")
      expect(response.body).to include("Not run (1)")
    end

    it "shows empty state when no test cases" do
      get my_work_path
      expect(response.body).to include("haven't created any test cases yet")
    end

    it "shows total test cases count badge" do
      create(:test_case, project: project, created_by: user)
      create(:test_case, project: project, created_by: user)
      get my_work_path
      expect(response.body).to include(">2<")
    end

    # ===== Multi-tenancy =====

    it "only shows data from current organization" do
      # Create data in current org
      req = create(:requirement, section: section, project: project, created_by: user, title: "Our Req")
      create(:test_case, project: project, created_by: user, title: "Our TC")

      # Create data in other org
      other_org = create(:organization)
      create(:membership, user: user, organization: other_org, role: :author)
      other_project = create(:project, organization: other_org)
      other_mod = create(:requirement_module, project: other_project)
      other_sec = create(:section, requirement_module: other_mod)
      create(:requirement, section: other_sec, project: other_project, created_by: user, title: "Other Org Req")
      create(:test_case, project: other_project, created_by: user, title: "Other Org TC")

      get my_work_path
      expect(response.body).to include("Our Req")
      expect(response.body).to include("Our TC")
      expect(response.body).not_to include("Other Org Req")
      expect(response.body).not_to include("Other Org TC")
    end

    # ===== Role Access =====

    context "when user is a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "allows access" do
        get my_work_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is an admin" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }

      it "allows access" do
        get my_work_path
        expect(response).to have_http_status(:success)
      end
    end
  end
end
