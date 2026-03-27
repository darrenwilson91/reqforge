require "rails_helper"

RSpec.describe "Search", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }

  let(:project) { create(:project, organization: organization, prefix: "SRCH") }
  let(:mod) { create(:requirement_module, project: project, name: "Search Module") }
  let(:section) { create(:section, requirement_module: mod, name: "Search Section") }

  let!(:req1) do
    create(:requirement,
      project: project, section: section, created_by: user,
      uid: "SRCH-0001", title: "Braking system shall respond within 100ms",
      body: "The emergency braking actuator must engage promptly"
    )
  end

  let!(:req2) do
    create(:requirement,
      project: project, section: section, created_by: user,
      uid: "SRCH-0002", title: "Steering control interface",
      body: "Steering inputs shall be processed with low latency"
    )
  end

  let!(:req3) do
    create(:requirement,
      project: project, section: section, created_by: user,
      uid: "SRCH-0003", title: "Sensor calibration procedure",
      body: "Sensors must be calibrated before each test run"
    )
  end

  before { sign_in user }

  describe "GET /search" do
    it "redirects unauthenticated users" do
      sign_out user
      get search_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the search page" do
      get search_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Search Results")
    end

    it "shows empty state when no query" do
      get search_path
      expect(response.body).to include("Search requirements")
      expect(response.body).to include("Enter a search term")
    end

    it "finds requirements by title" do
      get search_path, params: { q: "braking" }
      expect(response.body).to include("SRCH-0001")
      expect(response.body).to include("Braking system")
      expect(response.body).not_to include("SRCH-0002")
    end

    it "finds requirements by body" do
      get search_path, params: { q: "calibrated" }
      expect(response.body).to include("SRCH-0003")
      expect(response.body).to include("Sensor calibration")
    end

    it "finds requirements by UID" do
      get search_path, params: { q: "SRCH-0002" }
      expect(response.body).to include("SRCH-0002")
      expect(response.body).to include("Steering control")
    end

    it "finds requirements by prefix match" do
      get search_path, params: { q: "SRCH" }
      expect(response.body).to include("SRCH-0001")
      expect(response.body).to include("SRCH-0002")
      expect(response.body).to include("SRCH-0003")
    end

    it "shows no results message for unmatched query" do
      get search_path, params: { q: "nonexistent_xyz" }
      expect(response.body).to include("No results found")
      expect(response.body).to include("nonexistent_xyz")
    end

    it "shows result count" do
      get search_path, params: { q: "SRCH" }
      expect(response.body).to include("3 results")
    end

    it "shows project name in results" do
      get search_path, params: { q: "braking" }
      expect(response.body).to include(project.name)
    end

    it "shows module and section in results" do
      get search_path, params: { q: "braking" }
      expect(response.body).to include("Search Module")
      expect(response.body).to include("Search Section")
    end

    it "links to requirement show page" do
      get search_path, params: { q: "braking" }
      expect(response.body).to include(project_requirement_path(project, req1))
    end

    it "shows breadcrumbs" do
      get search_path, params: { q: "braking" }
      expect(response.body).to include("Search Results")
    end

    context "multi-tenancy" do
      let(:other_org) { create(:organization) }
      let(:other_project) { create(:project, organization: other_org, prefix: "OTHER") }
      let(:other_mod) { create(:requirement_module, project: other_project) }
      let(:other_section) { create(:section, requirement_module: other_mod) }
      let(:other_user) { create(:user) }
      let!(:other_membership) { create(:membership, user: other_user, organization: other_org) }

      let!(:other_req) do
        create(:requirement,
          project: other_project, section: other_section, created_by: other_user,
          uid: "OTHER-0001", title: "Braking system in other org"
        )
      end

      it "only returns requirements from current organization" do
        get search_path, params: { q: "braking" }
        expect(response.body).to include("SRCH-0001")
        expect(response.body).not_to include("OTHER-0001")
      end
    end

    context "with multiple projects" do
      let(:project2) { create(:project, organization: organization, prefix: "PRJ2") }
      let(:mod2) { create(:requirement_module, project: project2) }
      let(:section2) { create(:section, requirement_module: mod2) }

      let!(:req_in_project2) do
        create(:requirement,
          project: project2, section: section2, created_by: user,
          uid: "PRJ2-0001", title: "Cross-project braking test"
        )
      end

      it "searches across all projects in organization" do
        get search_path, params: { q: "braking" }
        expect(response.body).to include("SRCH-0001")
        expect(response.body).to include("PRJ2-0001")
      end
    end

    context "role-based access" do
      it "allows viewer to search" do
        viewer = create(:user)
        create(:membership, user: viewer, organization: organization, role: :viewer)
        sign_in viewer

        get search_path, params: { q: "braking" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("SRCH-0001")
      end
    end
  end

  describe "GET /search/autocomplete" do
    it "returns matching results as HTML partial" do
      get search_autocomplete_path, params: { q: "braking" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("SRCH-0001")
      expect(response.body).to include("Braking system")
    end

    it "returns empty state for no matches" do
      get search_autocomplete_path, params: { q: "nonexistent_xyz" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No requirements match")
    end

    it "returns empty for blank query" do
      get search_autocomplete_path, params: { q: "" }
      expect(response).to have_http_status(:ok)
      # Empty results should still render partial
    end

    it "limits results to 8" do
      10.times do |i|
        create(:requirement,
          project: project, section: section, created_by: user,
          title: "Autocomplete test requirement #{i}")
      end

      get search_autocomplete_path, params: { q: "autocomplete" }
      expect(response).to have_http_status(:ok)
      # Count the number of result links (each result is an <a> with rf-uid)
      expect(response.body.scan("rf-uid").count).to be <= 8
    end

    it "shows project prefix in results" do
      get search_autocomplete_path, params: { q: "braking" }
      expect(response.body).to include("SRCH")
    end

    it "includes view all results link" do
      get search_autocomplete_path, params: { q: "braking" }
      expect(response.body).to include("View all results")
      expect(response.body).to include(search_path(q: "braking"))
    end

    it "does not return results from other organizations" do
      other_org = create(:organization)
      other_project = create(:project, organization: other_org, prefix: "XORG")
      other_mod = create(:requirement_module, project: other_project)
      other_section = create(:section, requirement_module: other_mod)
      other_user = create(:user)
      create(:membership, user: other_user, organization: other_org)
      create(:requirement,
        project: other_project, section: other_section, created_by: other_user,
        uid: "XORG-0001", title: "Braking in other org"
      )

      get search_autocomplete_path, params: { q: "braking" }
      expect(response.body).to include("SRCH-0001")
      expect(response.body).not_to include("XORG-0001")
    end

    it "redirects unauthenticated users" do
      sign_out user
      get search_autocomplete_path, params: { q: "test" }
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
