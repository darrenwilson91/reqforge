require "rails_helper"

RSpec.describe "Traceability", type: :system do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization) }
  let(:req_module) { create(:requirement_module, project: project, name: "System Requirements") }
  let(:section) { create(:section, requirement_module: req_module, name: "Functional") }

  before { sign_in user }

  def create_req(**attrs)
    create(:requirement, project: project, section: section, created_by: user, **attrs)
  end

  describe "traceability links on requirement detail" do
    let!(:source) { create_req(title: "Source Requirement") }
    let!(:target) { create_req(title: "Target Requirement") }

    it "shows empty traceability section when no links exist" do
      visit project_requirement_path(project, source)
      expect(page).to have_content("Traceability Links")
      expect(page).to have_content("No traceability links")
    end

    it "shows traceability links grouped by type" do
      create(:traceability_link,
        source_requirement: source,
        target_requirement: target,
        link_type: :derives_from,
        created_by: user
      )

      visit project_requirement_path(project, source)
      expect(page).to have_content("Derives from")
      expect(page).to have_content(target.uid)
      expect(page).to have_content(target.title)
    end

    it "shows both outgoing and incoming links" do
      other = create_req(title: "Other Req")

      create(:traceability_link,
        source_requirement: source,
        target_requirement: target,
        link_type: :derives_from,
        created_by: user
      )
      create(:traceability_link,
        source_requirement: other,
        target_requirement: source,
        link_type: :satisfies,
        created_by: user
      )

      visit project_requirement_path(project, source)
      expect(page).to have_content(target.uid)
      expect(page).to have_content(other.uid)
    end

    it "shows the Add Link form for authorized users" do
      visit project_requirement_path(project, source)
      expect(page).to have_button("Add Link")
    end

    it "hides the Add Link form for viewers" do
      viewer = create(:user)
      create(:membership, user: viewer, organization: organization, role: :viewer)
      sign_in viewer

      visit project_requirement_path(project, source)
      expect(page).not_to have_button("Add Link")
    end

    it "shows delete buttons for authorized users on links" do
      create(:traceability_link,
        source_requirement: source,
        target_requirement: target,
        link_type: :derives_from,
        created_by: user
      )

      visit project_requirement_path(project, source)
      expect(page).to have_css("button[data-turbo-confirm]")
    end
  end

  describe "traceability matrix" do
    it "shows empty state when no links exist" do
      create_req(title: "Lonely Req")

      visit project_traceability_matrix_path(project)
      expect(page).to have_content("Traceability Matrix")
      expect(page).to have_content("No traceability links yet")
    end

    context "with links" do
      let(:mod_a) { create(:requirement_module, project: project, name: "Module A") }
      let(:mod_b) { create(:requirement_module, project: project, name: "Module B") }
      let(:sec_a) { create(:section, requirement_module: mod_a) }
      let(:sec_b) { create(:section, requirement_module: mod_b) }
      let!(:req_a) { create(:requirement, project: project, section: sec_a, created_by: user, title: "Req Alpha") }
      let!(:req_b) { create(:requirement, project: project, section: sec_b, created_by: user, title: "Req Beta") }
      let!(:link) do
        create(:traceability_link,
          source_requirement: req_a,
          target_requirement: req_b,
          link_type: :derives_from,
          created_by: user
        )
      end

      it "shows the matrix grid with requirement UIDs" do
        visit project_traceability_matrix_path(project)
        expect(page).to have_content(req_a.uid)
        expect(page).to have_content(req_b.uid)
      end

      it "shows coverage summary cards" do
        visit project_traceability_matrix_path(project)
        expect(page).to have_content("Total")
        expect(page).to have_content("Linked")
        expect(page).to have_content("Coverage")
      end

      it "shows the legend" do
        visit project_traceability_matrix_path(project)
        expect(page).to have_content("Legend:")
      end

      it "shows breadcrumb navigation" do
        visit project_traceability_matrix_path(project)
        expect(page).to have_link("Projects")
        expect(page).to have_link(project.name)
        expect(page).to have_content("Traceability Matrix")
      end

      it "has navigation to graph view" do
        visit project_traceability_matrix_path(project)
        expect(page).to have_link("Graph View")
      end

      it "has navigation to requirements" do
        visit project_traceability_matrix_path(project)
        expect(page).to have_link("Requirements")
      end

      it "shows filter controls" do
        visit project_traceability_matrix_path(project)
        expect(page).to have_select("source_module")
        expect(page).to have_select("target_module")
        expect(page).to have_button("Filter")
      end

      it "shows coverage by link type table" do
        visit project_traceability_matrix_path(project)
        expect(page).to have_content("Coverage by Link Type")
      end

      it "shows forward and backward coverage" do
        visit project_traceability_matrix_path(project)
        expect(page).to have_content("Forward")
        expect(page).to have_content("Backward")
      end
    end

    it "shows unlinked requirements warning" do
      req_a = create_req(title: "Linked Req A")
      req_b = create_req(title: "Linked Req B")
      unlinked = create_req(title: "Unlinked Req C")
      create(:traceability_link,
        source_requirement: req_a,
        target_requirement: req_b,
        link_type: :derives_from,
        created_by: user
      )

      visit project_traceability_matrix_path(project)
      expect(page).to have_content("Unlinked Requirements")
      expect(page).to have_content(unlinked.uid)
    end
  end

  describe "traceability graph" do
    it "shows empty state when no links exist" do
      visit project_traceability_graph_path(project)
      expect(page).to have_content("Traceability Graph")
      expect(page).to have_content("No traceability links yet")
    end

    context "with links" do
      let!(:source) { create_req(title: "Source Req") }
      let!(:target) { create_req(title: "Target Req") }
      let!(:link) do
        create(:traceability_link,
          source_requirement: source,
          target_requirement: target,
          link_type: :verifies,
          created_by: user
        )
      end

      it "shows the graph page with SVG canvas" do
        visit project_traceability_graph_path(project)
        expect(page).to have_css("[data-controller='graph']")
        expect(page).to have_css("svg")
      end

      it "shows requirement and link counts" do
        visit project_traceability_graph_path(project)
        expect(page).to have_content("2 requirements")
        expect(page).to have_content("1 link")
      end

      it "shows breadcrumb navigation" do
        visit project_traceability_graph_path(project)
        expect(page).to have_link("Projects")
        expect(page).to have_link(project.name)
        expect(page).to have_content("Traceability Graph")
      end

      it "has navigation to matrix view" do
        visit project_traceability_graph_path(project)
        expect(page).to have_link("Matrix View")
      end

      it "shows the link type legend" do
        visit project_traceability_graph_path(project)
        expect(page).to have_content("Link Types")
      end

      it "shows the module legend" do
        visit project_traceability_graph_path(project)
        expect(page).to have_content("Modules")
        expect(page).to have_content(req_module.name)
      end

      it "shows coverage summary cards" do
        visit project_traceability_graph_path(project)
        expect(page).to have_content("Total Requirements")
        expect(page).to have_content("Linked")
        expect(page).to have_content("Coverage")
      end
    end
  end

  describe "navigation between traceability views" do
    let!(:source) { create_req(title: "Nav Source") }
    let!(:target) { create_req(title: "Nav Target") }
    let!(:link) do
      create(:traceability_link,
        source_requirement: source,
        target_requirement: target,
        link_type: :satisfies,
        created_by: user
      )
    end

    it "navigates from project show to matrix" do
      visit project_path(project)
      click_link "Traceability"
      expect(page).to have_content("Traceability Matrix")
    end

    it "navigates from matrix to graph" do
      visit project_traceability_matrix_path(project)
      click_link "Graph View"
      expect(page).to have_content("Traceability Graph")
    end

    it "navigates from graph to matrix" do
      visit project_traceability_graph_path(project)
      click_link "Matrix View"
      expect(page).to have_content("Traceability Matrix")
    end

    it "navigates from matrix to requirements" do
      visit project_traceability_matrix_path(project)
      # Click the Requirements button in the header area
      all("a", text: "Requirements").last.click
      expect(page).to have_current_path(project_requirements_path(project))
    end
  end

  describe "role-based access" do
    let!(:req1) { create_req(title: "RBA Req 1") }
    let!(:req2) { create_req(title: "RBA Req 2") }

    it "allows viewers to see the matrix" do
      viewer = create(:user)
      create(:membership, user: viewer, organization: organization, role: :viewer)
      sign_in viewer

      visit project_traceability_matrix_path(project)
      expect(page).to have_content("Traceability Matrix")
    end

    it "allows viewers to see the graph" do
      viewer = create(:user)
      create(:membership, user: viewer, organization: organization, role: :viewer)
      sign_in viewer

      visit project_traceability_graph_path(project)
      expect(page).to have_content("Traceability Graph")
    end
  end
end
