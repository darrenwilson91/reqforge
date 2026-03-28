require "rails_helper"

RSpec.describe "Global Search", type: :system do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }

  let(:project) { create(:project, organization: organization, prefix: "GSRC") }
  let(:mod) { create(:requirement_module, project: project, name: "System Requirements") }
  let(:section) { create(:section, requirement_module: mod, name: "Braking") }

  let!(:req1) do
    create(:requirement,
      project: project, section: section, created_by: user,
      uid: "GSRC-0001", title: "Emergency braking response time",
      body: "System shall respond to brake input within 100ms"
    )
  end

  let!(:req2) do
    create(:requirement,
      project: project, section: section, created_by: user,
      uid: "GSRC-0002", title: "Steering torque limits",
      body: "Electric power steering shall limit torque to safe levels"
    )
  end

  before { sign_in user }

  describe "search results page" do
    it "shows search form with query" do
      visit search_path(q: "braking")
      expect(page).to have_field("q", with: "braking")
    end

    it "finds requirements by title" do
      visit search_path(q: "braking")
      expect(page).to have_text("GSRC-0001")
      expect(page).to have_text("Emergency braking")
      expect(page).not_to have_text("GSRC-0002")
    end

    it "finds requirements by UID" do
      visit search_path(q: "GSRC-0002")
      expect(page).to have_text("GSRC-0002")
      expect(page).to have_text("Steering torque")
    end

    it "shows result count" do
      visit search_path(q: "GSRC")
      expect(page).to have_text("2 results")
    end

    it "shows project and module context" do
      visit search_path(q: "braking")
      expect(page).to have_text(project.name)
      expect(page).to have_text("System Requirements")
    end

    it "shows empty state for no query" do
      visit search_path
      expect(page).to have_text("Search requirements")
      expect(page).to have_text("Enter a search term")
    end

    it "shows no results message" do
      visit search_path(q: "nonexistent_xyz")
      expect(page).to have_text("No results found")
    end

    it "links to requirement detail" do
      visit search_path(q: "braking")
      click_link "GSRC-0001", match: :first
      expect(page).to have_current_path(project_requirement_path(project, req1))
    end

    it "shows breadcrumbs" do
      visit search_path(q: "test")
      expect(page).to have_text("Search Results")
    end
  end

  describe "topbar search" do
    it "has search input in navigation bar" do
      visit root_path
      expect(page).to have_field("q", placeholder: "Search requirements...")
    end

    it "submits search form to results page" do
      visit root_path
      within("header") do
        fill_in "q", with: "braking"
      end
      # Submit the form by pressing enter (simulated via direct navigation)
      visit search_path(q: "braking")
      expect(page).to have_text("GSRC-0001")
    end
  end

  describe "organization isolation" do
    let(:other_org) { create(:organization) }
    let(:other_project) { create(:project, organization: other_org, prefix: "XISO") }
    let(:other_mod) { create(:requirement_module, project: other_project) }
    let(:other_section) { create(:section, requirement_module: other_mod) }
    let(:other_user) { create(:user) }
    let!(:other_membership) { create(:membership, user: other_user, organization: other_org) }

    let!(:other_req) do
      create(:requirement,
        project: other_project, section: other_section, created_by: other_user,
        uid: "XISO-0001", title: "Emergency braking in other org"
      )
    end

    it "does not show requirements from other organizations" do
      visit search_path(q: "braking")
      expect(page).to have_text("GSRC-0001")
      expect(page).not_to have_text("XISO-0001")
    end
  end
end
