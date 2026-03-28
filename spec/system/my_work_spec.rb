require "rails_helper"

RSpec.describe "My Work Page", type: :system do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, first_name: "Alice") }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :author) }
  let!(:project) { create(:project, organization: organization, name: "Brake System") }
  let!(:mod) { create(:requirement_module, project: project, name: "System Req") }
  let!(:section) { create(:section, requirement_module: mod, name: "Safety") }

  before { login_as(user, scope: :user) }

  describe "page layout" do
    it "shows page title and subtitle" do
      visit my_work_path
      expect(page).to have_content("My Work")
      expect(page).to have_content("Your requirements, change sets, reviews, and test cases across all projects")
    end

    it "shows summary stat cards" do
      visit my_work_path
      expect(page).to have_content("My Requirements")
      expect(page).to have_content("Active Change Sets")
      expect(page).to have_content("Pending Reviews")
      expect(page).to have_content("My Test Cases")
    end
  end

  describe "my requirements" do
    it "shows authored requirements" do
      req = create(:requirement, section: section, project: project, created_by: user, title: "Brake Force Limit")
      visit my_work_path
      expect(page).to have_content("Brake Force Limit")
      expect(page).to have_content(req.uid)
      expect(page).to have_content("Brake System")
    end

    it "shows empty state when no requirements" do
      visit my_work_path
      expect(page).to have_content("haven't authored any requirements yet")
    end

    it "hides other users' requirements" do
      other = create(:user)
      create(:requirement, section: section, project: project, created_by: other, title: "Not Mine")
      visit my_work_path
      expect(page).not_to have_content("Not Mine")
    end

    it "shows status filter pills" do
      create(:requirement, section: section, project: project, created_by: user, status: :draft)
      create(:requirement, section: section, project: project, created_by: user, status: :approved)
      visit my_work_path
      expect(page).to have_content("All")
      expect(page).to have_content("Draft (1)")
      expect(page).to have_content("Approved (1)")
    end

    it "filters by status when clicking a pill" do
      create(:requirement, section: section, project: project, created_by: user, title: "Draft Req", status: :draft)
      create(:requirement, section: section, project: project, created_by: user, title: "Approved Req", status: :approved)
      visit my_work_path(req_status: "draft")
      expect(page).to have_content("Draft Req")
      expect(page).not_to have_content("Approved Req")
    end

    it "shows requirement status and type badges" do
      create(:requirement, section: section, project: project, created_by: user, title: "Safety Req",
             requirement_type: :safety, status: :approved)
      visit my_work_path
      expect(page).to have_content("Safety")
      expect(page).to have_content("Approved")
    end

    it "links requirement UIDs to detail pages" do
      req = create(:requirement, section: section, project: project, created_by: user, title: "Test Req")
      visit my_work_path
      expect(page).to have_link(req.uid, href: project_requirement_path(project, req))
    end
  end

  describe "needs your review" do
    it "hides section when no pending reviews" do
      visit my_work_path
      expect(page).not_to have_content("Needs Your Review")
    end

    it "shows pending change set reviews" do
      other = create(:user, first_name: "Bob", last_name: "Author")
      create(:membership, user: other, organization: organization, role: :author)
      cs = create(:change_set, project: project, created_by: other, title: "Bob's Feature", status: :in_review)
      create(:change_set_approval, change_set: cs, user: user, status: :pending)
      visit my_work_path
      expect(page).to have_content("Needs Your Review")
      expect(page).to have_content("Bob's Feature")
      expect(page).to have_content("Bob Author")
    end

    it "shows change set status badge" do
      other = create(:user)
      create(:membership, user: other, organization: organization, role: :author)
      cs = create(:change_set, project: project, created_by: other, title: "CS", status: :in_review)
      create(:change_set_approval, change_set: cs, user: user, status: :pending)
      visit my_work_path
      expect(page).to have_content("In review")
    end
  end

  describe "active formal reviews" do
    it "hides section when no active reviews" do
      visit my_work_path
      expect(page).not_to have_content("Active Formal Reviews")
    end

    it "shows active reviews where user is participant" do
      review = create(:review, project: project, created_by: user, title: "Q1 Safety Review", status: :in_progress)
      create(:review_participant, review: review, user: user, role: :reviewer)
      visit my_work_path
      expect(page).to have_content("Active Formal Reviews")
      expect(page).to have_content("Q1 Safety Review")
      # Role is rendered with CSS capitalize class, HTML text is lowercase
      expect(page).to have_content("reviewer")
    end
  end

  describe "my change sets" do
    it "shows active change sets" do
      create(:change_set, project: project, created_by: user, title: "My Feature Work", status: :draft)
      visit my_work_path
      expect(page).to have_content("My Change Sets")
      expect(page).to have_content("My Feature Work")
    end

    it "shows empty state when no active change sets" do
      visit my_work_path
      expect(page).to have_content("No active change sets")
    end

    it "excludes merged and closed change sets" do
      create(:change_set, project: project, created_by: user, title: "Merged One", status: :merged)
      create(:change_set, project: project, created_by: user, title: "Closed One", status: :closed)
      visit my_work_path
      expect(page).not_to have_content("Merged One")
      expect(page).not_to have_content("Closed One")
    end

    it "shows change set project name" do
      create(:change_set, project: project, created_by: user, title: "My CS", status: :draft)
      visit my_work_path
      expect(page).to have_content("Brake System")
    end
  end

  describe "my test cases" do
    it "shows test cases created by user" do
      tc = create(:test_case, project: project, created_by: user, title: "Brake Endurance Test")
      visit my_work_path
      expect(page).to have_content("My Test Cases")
      expect(page).to have_content("Brake Endurance Test")
      expect(page).to have_content(tc.uid)
    end

    it "shows empty state when no test cases" do
      visit my_work_path
      expect(page).to have_content("haven't created any test cases yet")
    end

    it "shows test case status and type badges" do
      create(:test_case, project: project, created_by: user, title: "System TC",
             test_type: :system, status: :failed)
      visit my_work_path
      expect(page).to have_content("System")
      expect(page).to have_content("Failed")
    end

    it "shows linked requirement UID" do
      req = create(:requirement, section: section, project: project, created_by: user)
      create(:test_case, project: project, created_by: user, requirement: req)
      visit my_work_path
      expect(page).to have_content(req.uid)
    end

    it "shows status distribution badges" do
      create(:test_case, project: project, created_by: user, status: :passed)
      create(:test_case, project: project, created_by: user, status: :failed)
      visit my_work_path
      expect(page).to have_content("Passed (1)")
      expect(page).to have_content("Failed (1)")
    end

    it "links test case UIDs to detail pages" do
      tc = create(:test_case, project: project, created_by: user, title: "My TC")
      visit my_work_path
      expect(page).to have_link(tc.uid, href: project_test_case_path(project, tc))
    end
  end

  describe "sidebar navigation" do
    it "shows My Work link in sidebar" do
      visit root_path
      expect(page).to have_content("My Work")
    end
  end

  describe "organization isolation" do
    it "only shows data from current organization" do
      create(:requirement, section: section, project: project, created_by: user, title: "Our Requirement")

      other_org = create(:organization)
      create(:membership, user: user, organization: other_org, role: :author)
      other_project = create(:project, organization: other_org)
      other_mod = create(:requirement_module, project: other_project)
      other_sec = create(:section, requirement_module: other_mod)
      create(:requirement, section: other_sec, project: other_project, created_by: user, title: "Other Org Req")

      visit my_work_path
      expect(page).to have_content("Our Requirement")
      expect(page).not_to have_content("Other Org Req")
    end
  end

  describe "role access" do
    context "viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "allows access" do
        visit my_work_path
        expect(page).to have_content("My Work")
      end
    end

    context "admin" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }

      it "allows access" do
        visit my_work_path
        expect(page).to have_content("My Work")
      end
    end
  end
end
