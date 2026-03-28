require "rails_helper"

RSpec.describe "Dashboard Metrics", type: :system do
  let(:organization) { create(:organization) }

  describe "manager dashboard" do
    let(:admin) { create(:user, first_name: "Admin") }
    let!(:membership) { create(:membership, user: admin, organization: organization, role: :admin) }
    let!(:project) { create(:project, organization: organization, name: "Brake System") }
    let!(:mod) { create(:requirement_module, project: project, name: "System Req") }
    let!(:section) { create(:section, requirement_module: mod, name: "Safety") }

    before { login_as(admin, scope: :user) }

    it "shows manager subtitle for admins" do
      visit root_path
      expect(page).to have_content("Organization overview and team performance")
    end

    it "shows stat cards" do
      visit root_path
      expect(page).to have_content("Projects")
      expect(page).to have_content("Requirements")
      expect(page).to have_content("Active Reviews")
      expect(page).to have_content("Team Members")
    end

    it "shows approval rate metric" do
      create(:requirement, section: section, project: project, created_by: admin, status: :approved)
      create(:requirement, section: section, project: project, created_by: admin, status: :draft)
      visit root_path
      expect(page).to have_content("Approval Rate")
      expect(page).to have_content("50%")
    end

    it "shows reviews completed metric" do
      create(:review, project: project, created_by: admin, status: :completed)
      create(:review, project: project, created_by: admin, status: :in_progress)
      visit root_path
      expect(page).to have_content("Reviews Completed")
    end

    it "shows open and merged change set counts" do
      create(:change_set, project: project, created_by: admin, status: :draft)
      create(:change_set, project: project, created_by: admin, status: :merged)
      visit root_path
      expect(page).to have_content("Open Change Sets")
      expect(page).to have_content("Merged Change Sets")
    end

    it "shows test case summary" do
      create(:test_case, project: project, created_by: admin, status: :passed)
      create(:test_case, project: project, created_by: admin, status: :failed)
      visit root_path
      expect(page).to have_content("Test Cases")
      expect(page).to have_content("1 passed")
      expect(page).to have_content("1 failed")
    end

    it "shows requirement status breakdown" do
      create(:requirement, section: section, project: project, created_by: admin, status: :draft)
      create(:requirement, section: section, project: project, created_by: admin, status: :approved)
      visit root_path
      expect(page).to have_content("Requirement Status Breakdown")
      expect(page).to have_content("Draft")
      expect(page).to have_content("Approved")
    end

    it "shows review bottlenecks section" do
      visit root_path
      expect(page).to have_content("Review Bottlenecks")
    end

    it "shows overdue change sets" do
      create(:change_set, project: project, created_by: admin, title: "Old Changes",
             status: :in_review, created_at: 5.days.ago)
      visit root_path
      expect(page).to have_content("Old Changes")
    end

    it "shows no overdue reviews empty state" do
      visit root_path
      expect(page).to have_content("No overdue reviews")
    end

    it "shows outstanding approvals by reviewer" do
      reviewer = create(:user, first_name: "Bob", last_name: "Smith")
      create(:membership, user: reviewer, organization: organization, role: :reviewer)
      cs = create(:change_set, project: project, created_by: admin, status: :in_review)
      create(:change_set_approval, change_set: cs, user: reviewer, status: :pending)
      visit root_path
      expect(page).to have_content("Outstanding Approvals by Reviewer")
      expect(page).to have_content("Bob Smith")
      expect(page).to have_content("1 pending")
    end

    it "shows no outstanding approvals empty state" do
      visit root_path
      expect(page).to have_content("No outstanding approvals")
    end

    it "shows recent projects and requirements" do
      visit root_path
      expect(page).to have_content("Recent Projects")
      expect(page).to have_content("Brake System")
    end

    it "shows quick actions" do
      visit root_path
      expect(page).to have_content("New Project")
    end
  end

  describe "project manager dashboard" do
    let(:pm) { create(:user, first_name: "PM") }
    let!(:membership) { create(:membership, user: pm, organization: organization, role: :project_manager) }
    let!(:project) { create(:project, organization: organization) }

    before { login_as(pm, scope: :user) }

    it "shows manager view" do
      visit root_path
      expect(page).to have_content("Organization overview and team performance")
      expect(page).to have_content("Approval Rate")
    end
  end

  describe "engineer dashboard" do
    let(:author) { create(:user, first_name: "Alice") }
    let!(:membership) { create(:membership, user: author, organization: organization, role: :author) }
    let!(:project) { create(:project, organization: organization, name: "Brake System") }
    let!(:mod) { create(:requirement_module, project: project, name: "System Req") }
    let!(:section) { create(:section, requirement_module: mod, name: "Safety") }

    before { login_as(author, scope: :user) }

    it "shows engineer subtitle" do
      visit root_path
      expect(page).to have_content("Your requirements, reviews, and assignments")
    end

    it "shows role badge" do
      visit root_path
      expect(page).to have_content("Author")
    end

    it "shows my requirements section" do
      req = create(:requirement, section: section, project: project, created_by: author, title: "My Brake Req")
      visit root_path
      expect(page).to have_content("My Requirements")
      expect(page).to have_content("My Brake Req")
    end

    it "shows my requirements count" do
      create(:requirement, section: section, project: project, created_by: author)
      create(:requirement, section: section, project: project, created_by: author)
      visit root_path
      expect(page).to have_content("2 total")
    end

    it "shows my active change sets" do
      create(:change_set, project: project, created_by: author, title: "Alice Changes", status: :draft)
      visit root_path
      expect(page).to have_content("My Active Change Sets")
      expect(page).to have_content("Alice Changes")
    end

    it "shows pending reviews" do
      other = create(:user, first_name: "Bob")
      create(:membership, user: other, organization: organization, role: :author)
      cs = create(:change_set, project: project, created_by: other, title: "Bob's CS", status: :in_review)
      create(:change_set_approval, change_set: cs, user: author, status: :pending)
      visit root_path
      expect(page).to have_content("Pending Reviews")
      expect(page).to have_content("Bob's CS")
      expect(page).to have_content("Needs your review")
    end

    it "shows no pending reviews empty state" do
      visit root_path
      expect(page).to have_content("No pending reviews")
    end

    it "shows test cases needing attention" do
      create(:test_case, project: project, created_by: author, title: "Failed Brake Test", status: :failed)
      visit root_path
      expect(page).to have_content("My Test Cases Needing Attention")
      expect(page).to have_content("Failed Brake Test")
    end

    it "excludes passed and draft test cases from attention list" do
      create(:test_case, project: project, created_by: author, title: "Passed TC", status: :passed)
      create(:test_case, project: project, created_by: author, title: "Draft TC", status: :draft)
      visit root_path
      expect(page).not_to have_content("Passed TC")
      expect(page).not_to have_content("Draft TC")
    end

    it "does not show manager metrics" do
      visit root_path
      expect(page).not_to have_content("Approval Rate")
      expect(page).not_to have_content("Review Bottlenecks")
    end
  end

  describe "empty state" do
    let(:user) { create(:user) }
    let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }

    before { login_as(user, scope: :user) }

    it "shows getting started when no projects" do
      visit root_path
      expect(page).to have_content("Get started with ReqForge")
      expect(page).to have_content("Create First Project")
    end

    it "shows onboarding steps" do
      visit root_path
      expect(page).to have_content("Create a project")
      expect(page).to have_content("Add requirements")
      expect(page).to have_content("Build traceability")
    end
  end

  describe "organization isolation" do
    let(:user) { create(:user) }
    let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
    let!(:project) { create(:project, organization: organization, name: "Our Project") }
    let(:other_org) { create(:organization) }
    let!(:other_project) { create(:project, organization: other_org, name: "Other Project") }

    before { login_as(user, scope: :user) }

    it "only shows current organization data" do
      visit root_path
      expect(page).to have_content("Our Project")
      expect(page).not_to have_content("Other Project")
    end
  end
end
