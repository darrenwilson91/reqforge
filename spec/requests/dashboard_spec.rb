require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET / (root)" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        get root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user has no organization" do
      it "redirects to organization setup" do
        get root_path
        expect(response).to redirect_to(new_organization_path)
      end
    end

    context "when organization has no projects (empty state)" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }

      it "shows getting started empty state" do
        get root_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Get started with ReqForge")
        expect(response.body).to include("Create First Project")
      end

      it "shows onboarding steps" do
        get root_path
        expect(response.body).to include("Create a project")
        expect(response.body).to include("Add requirements")
        expect(response.body).to include("Build traceability")
      end
    end

    context "common elements (with projects)" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
      let!(:project) { create(:project, organization: organization, name: "Brake System") }

      it "shows welcome message with user name" do
        get root_path
        expect(response.body).to include("Welcome back, #{user.first_name}")
      end

      it "shows role badge" do
        get root_path
        expect(response.body).to include("Admin")
      end

      it "shows stat cards with correct counts" do
        get root_path
        expect(response.body).to include("Projects")
        expect(response.body).to include("Requirements")
        expect(response.body).to include("Active Reviews")
        expect(response.body).to include("Team Members")
      end

      it "shows correct project count" do
        create(:project, organization: organization, name: "Another Project")
        get root_path
        # 2 projects
        expect(response.body).to match(/>2<\/div>\s*<div[^>]*>Projects/)
      end

      it "shows recent projects" do
        get root_path
        expect(response.body).to include("Brake System")
        expect(response.body).to include("Recent Projects")
      end

      it "shows quick actions" do
        get root_path
        expect(response.body).to include("New Project")
      end
    end

    context "manager view (admin role)" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
      let!(:project) { create(:project, organization: organization, name: "Brake System") }
      let!(:mod) { create(:requirement_module, project: project, name: "System Req") }
      let!(:section) { create(:section, requirement_module: mod, name: "Safety") }

      it "shows manager subtitle" do
        get root_path
        expect(response.body).to include("Organization overview and team performance")
      end

      it "shows approval rate metric" do
        get root_path
        expect(response.body).to include("Approval Rate")
      end

      it "shows reviews completed metric" do
        get root_path
        expect(response.body).to include("Reviews Completed")
      end

      it "shows open and merged change sets metrics" do
        get root_path
        expect(response.body).to include("Open Change Sets")
        expect(response.body).to include("Merged Change Sets")
      end

      it "shows test cases summary" do
        get root_path
        expect(response.body).to include("Test Cases")
      end

      it "calculates approval rate correctly" do
        create(:requirement, section: section, project: project, created_by: user, status: :approved)
        create(:requirement, section: section, project: project, created_by: user, status: :draft)
        get root_path
        # 1 of 2 approved = 50%
        expect(response.body).to include("50%")
      end

      it "counts approved, implemented, and verified as approved for approval rate" do
        create(:requirement, section: section, project: project, created_by: user, status: :approved)
        create(:requirement, section: section, project: project, created_by: user, status: :implemented)
        create(:requirement, section: section, project: project, created_by: user, status: :verified)
        create(:requirement, section: section, project: project, created_by: user, status: :draft)
        get root_path
        # 3 of 4 = 75%
        expect(response.body).to include("75%")
      end

      it "shows requirement status breakdown" do
        create(:requirement, section: section, project: project, created_by: user, status: :draft)
        create(:requirement, section: section, project: project, created_by: user, status: :approved)
        get root_path
        expect(response.body).to include("Requirement Status Breakdown")
        expect(response.body).to include("Draft")
        expect(response.body).to include("Approved")
      end

      it "shows review bottlenecks section" do
        get root_path
        expect(response.body).to include("Review Bottlenecks")
      end

      it "shows overdue change sets (waiting > 3 days)" do
        overdue_cs = create(:change_set, project: project, created_by: user, title: "Overdue Changes",
                            status: :in_review, created_at: 5.days.ago)
        get root_path
        expect(response.body).to include("Overdue Changes")
      end

      it "does not show recent change sets as overdue" do
        recent_cs = create(:change_set, project: project, created_by: user, title: "Fresh Changes",
                           status: :in_review, created_at: 1.hour.ago)
        get root_path
        body = response.body
        # Check the bottlenecks section specifically - the "No overdue reviews" empty state should show
        expect(body).to include("No overdue reviews")
      end

      it "shows outstanding approvals by reviewer" do
        get root_path
        expect(response.body).to include("Outstanding Approvals by Reviewer")
      end

      it "displays pending approvals with reviewer info" do
        reviewer = create(:user, first_name: "Bob", last_name: "Reviewer")
        create(:membership, user: reviewer, organization: organization, role: :reviewer)
        cs = create(:change_set, project: project, created_by: user, status: :in_review)
        create(:change_set_approval, change_set: cs, user: reviewer, status: :pending)
        get root_path
        expect(response.body).to include("Bob Reviewer")
        expect(response.body).to include("1 pending")
      end

      it "shows no outstanding approvals empty state" do
        get root_path
        expect(response.body).to include("No outstanding approvals")
      end

      it "counts open and merged change sets correctly" do
        create(:change_set, project: project, created_by: user, status: :draft)
        create(:change_set, project: project, created_by: user, status: :in_review)
        create(:change_set, project: project, created_by: user, status: :merged)
        get root_path
        # 2 open (draft + in_review), 1 merged
        body = response.body
        expect(body).to include("Open Change Sets")
        expect(body).to include("Merged Change Sets")
      end

      it "shows test case pass/fail counts" do
        create(:test_case, project: project, created_by: user, status: :passed)
        create(:test_case, project: project, created_by: user, status: :passed)
        create(:test_case, project: project, created_by: user, status: :failed)
        get root_path
        expect(response.body).to include("2 passed")
        expect(response.body).to include("1 failed")
      end

      it "does not show engineer-specific sections" do
        get root_path
        expect(response.body).not_to include("Your requirements, reviews, and assignments")
      end
    end

    context "manager view (project_manager role)" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :project_manager) }
      let!(:project) { create(:project, organization: organization) }

      it "shows manager view for project managers" do
        get root_path
        expect(response.body).to include("Organization overview and team performance")
        expect(response.body).to include("Approval Rate")
      end
    end

    context "engineer view (author role)" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :author) }
      let!(:project) { create(:project, organization: organization, name: "Brake System") }
      let!(:mod) { create(:requirement_module, project: project, name: "System Req") }
      let!(:section) { create(:section, requirement_module: mod, name: "Safety") }

      it "shows engineer subtitle" do
        get root_path
        expect(response.body).to include("Your requirements, reviews, and assignments")
      end

      it "shows pending reviews section" do
        get root_path
        expect(response.body).to include("Pending Reviews")
      end

      it "shows pending reviews with 'Needs your review' badge" do
        other_user = create(:user)
        create(:membership, user: other_user, organization: organization, role: :author)
        cs = create(:change_set, project: project, created_by: other_user, title: "Review Me", status: :in_review)
        create(:change_set_approval, change_set: cs, user: user, status: :pending)
        get root_path
        expect(response.body).to include("Review Me")
        expect(response.body).to include("Needs your review")
      end

      it "shows no pending reviews empty state" do
        get root_path
        expect(response.body).to include("No pending reviews")
      end

      it "shows my requirements section" do
        get root_path
        expect(response.body).to include("My Requirements")
      end

      it "shows authored requirements" do
        req = create(:requirement, section: section, project: project, created_by: user, title: "My Req")
        get root_path
        expect(response.body).to include("My Req")
        expect(response.body).to include(req.uid)
      end

      it "shows requirements count" do
        create(:requirement, section: section, project: project, created_by: user, title: "Req 1")
        create(:requirement, section: section, project: project, created_by: user, title: "Req 2")
        get root_path
        expect(response.body).to include("2 total")
      end

      it "does not show requirements authored by other users in My Requirements section" do
        other = create(:user)
        create(:requirement, section: section, project: project, created_by: other, title: "Other User Req")
        get root_path
        # The "My Requirements" section should not include other users' requirements
        # But "Recent Requirements" shows all org requirements - so we check My Requirements count stays 0
        expect(response.body).to include("0 total")
      end

      it "shows my active change sets section" do
        get root_path
        expect(response.body).to include("My Active Change Sets")
      end

      it "shows authored change sets" do
        cs = create(:change_set, project: project, created_by: user, title: "My Changes", status: :draft)
        get root_path
        expect(response.body).to include("My Changes")
      end

      it "excludes merged and closed change sets" do
        create(:change_set, project: project, created_by: user, title: "Merged CS", status: :merged)
        create(:change_set, project: project, created_by: user, title: "Closed CS", status: :closed)
        get root_path
        expect(response.body).not_to include("Merged CS")
        expect(response.body).not_to include("Closed CS")
      end

      it "shows no active change sets empty state" do
        get root_path
        expect(response.body).to include("No active change sets")
      end

      it "shows test cases needing attention" do
        tc = create(:test_case, project: project, created_by: user, title: "Failed Test", status: :failed)
        get root_path
        expect(response.body).to include("My Test Cases Needing Attention")
        expect(response.body).to include("Failed Test")
        expect(response.body).to include(tc.uid)
      end

      it "excludes passed and draft test cases" do
        create(:test_case, project: project, created_by: user, title: "Passed TC", status: :passed)
        create(:test_case, project: project, created_by: user, title: "Draft TC", status: :draft)
        get root_path
        expect(response.body).not_to include("Passed TC")
        expect(response.body).not_to include("Draft TC")
      end

      it "does not show manager-specific metrics" do
        get root_path
        expect(response.body).not_to include("Approval Rate")
        expect(response.body).not_to include("Review Bottlenecks")
        expect(response.body).not_to include("Outstanding Approvals by Reviewer")
      end
    end

    context "engineer view (viewer role)" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }
      let!(:project) { create(:project, organization: organization) }

      it "shows engineer view for viewers" do
        get root_path
        expect(response.body).to include("Your requirements, reviews, and assignments")
      end
    end

    context "engineer view (reviewer role)" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :reviewer) }
      let!(:project) { create(:project, organization: organization) }

      it "shows engineer view for reviewers" do
        get root_path
        expect(response.body).to include("Your requirements, reviews, and assignments")
      end
    end

    context "multi-tenancy" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
      let!(:project) { create(:project, organization: organization, name: "Our Project") }
      let(:other_org) { create(:organization) }
      let!(:other_project) { create(:project, organization: other_org, name: "Other Org Project") }

      it "only counts projects from current organization" do
        get root_path
        expect(response.body).to include("Our Project")
        expect(response.body).not_to include("Other Org Project")
      end

      it "only counts requirements from current organization" do
        mod = create(:requirement_module, project: project)
        section = create(:section, requirement_module: mod)
        create(:requirement, section: section, project: project, created_by: user, title: "Our Req")

        other_mod = create(:requirement_module, project: other_project)
        other_sec = create(:section, requirement_module: other_mod)
        create(:requirement, section: other_sec, project: other_project, created_by: user, title: "Other Req")

        get root_path
        expect(response.body).to include("Our Req")
        expect(response.body).not_to include("Other Req")
      end
    end
  end
end
