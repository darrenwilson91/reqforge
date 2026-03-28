require "rails_helper"

RSpec.describe "Project Management", type: :system do
  let(:organization) { create(:organization, name: "Acme Engineering") }
  let(:user) { create(:user, first_name: "Jane", last_name: "Doe") }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }

  before { sign_in user }

  describe "projects index" do
    it "shows the projects page with heading" do
      visit projects_path
      expect(page).to have_content("Projects")
      expect(page).to have_link("New Project")
    end

    it "shows empty state when no projects exist" do
      visit projects_path
      expect(page).to have_content("No projects yet")
      expect(page).to have_content("Create your first project")
    end

    it "lists existing projects as cards" do
      create(:project, organization: organization, name: "Brake Controller", prefix: "BRK", description: "Brake ECU project")
      create(:project, organization: organization, name: "Steering Unit", prefix: "STR")
      visit projects_path
      expect(page).to have_content("Brake Controller")
      expect(page).to have_content("BRK")
      expect(page).to have_content("Brake ECU project")
      expect(page).to have_content("Steering Unit")
      expect(page).to have_content("STR")
    end

    it "shows module and requirement counts on project cards" do
      project = create(:project, organization: organization, name: "Test Project", prefix: "TST")
      mod = create(:requirement_module, project: project, name: "Module 1")
      section = create(:section, requirement_module: mod, name: "Section 1")
      create(:requirement, section: section, project: project, created_by: user)
      visit projects_path
      expect(page).to have_content("1 module")
      expect(page).to have_content("1 requirement")
    end

    it "does not show projects from other organizations" do
      other_org = create(:organization, name: "Other Corp")
      create(:project, organization: other_org, name: "Secret Project", prefix: "SEC")
      visit projects_path
      expect(page).not_to have_content("Secret Project")
    end
  end

  describe "creating a new project" do
    it "creates a project with valid data" do
      visit new_project_path
      fill_in "Name", with: "Vehicle Control Unit"
      fill_in "Prefix", with: "VCU"
      fill_in "Description", with: "Main ECU requirements project"
      click_button "Create Project"

      expect(page).to have_content("Project created successfully")
      expect(page).to have_content("Vehicle Control Unit")
      expect(page).to have_content("VCU")
      expect(page).to have_content("Main ECU requirements project")
    end

    it "shows validation errors for invalid data" do
      visit new_project_path
      fill_in "Name", with: ""
      fill_in "Prefix", with: ""
      click_button "Create Project"

      expect(page).to have_content("error")
    end

    it "shows validation error for invalid prefix format" do
      visit new_project_path
      fill_in "Name", with: "Test"
      fill_in "Prefix", with: "lowercase"
      click_button "Create Project"

      expect(page).to have_content("error")
    end

    it "navigates from index to new project form" do
      visit projects_path
      click_link "New Project", match: :first
      expect(page).to have_button("Create Project")
    end

    it "can cancel and return to projects list" do
      visit new_project_path
      click_link "Cancel"
      expect(page).to have_current_path(projects_path)
    end

    context "with compliance templates" do
      before do
        ComplianceTemplate.create!(name: "ISO 26262 — Functional Safety", standard: "iso_26262", template_data: ComplianceTemplate.iso_26262_template_data)
        ComplianceTemplate.create!(name: "Automotive SPICE", standard: "aspice", template_data: ComplianceTemplate.aspice_template_data)
      end

      it "shows the compliance template selector" do
        visit new_project_path
        expect(page).to have_content("Compliance Template")
        expect(page).to have_select("compliance_template_id")
      end

      it "lists available templates in the selector" do
        visit new_project_path
        expect(page).to have_select("compliance_template_id", with_options: [
          "None — blank project",
          "ISO 26262 — Functional Safety (ISO 26262)",
          "Automotive SPICE (ASPICE)"
        ])
      end

      it "creates a project with an ISO 26262 template" do
        visit new_project_path
        fill_in "Name", with: "Safety ECU"
        fill_in "Prefix", with: "SEC"
        select "ISO 26262 — Functional Safety (ISO 26262)", from: "compliance_template_id"
        click_button "Create Project"

        expect(page).to have_content("Project created successfully")
        project = Project.last
        expect(project.requirement_modules.count).to eq(7)
        expect(project.attribute_schema.length).to eq(4)
      end

      it "creates a project without a template when None is selected" do
        visit new_project_path
        fill_in "Name", with: "Plain Project"
        fill_in "Prefix", with: "PLN"
        select "None — blank project", from: "compliance_template_id"
        click_button "Create Project"

        expect(page).to have_content("Project created successfully")
        project = Project.last
        expect(project.requirement_modules.count).to eq(0)
      end
    end
  end

  describe "viewing a project" do
    let!(:project) { create(:project, organization: organization, name: "Brake Controller", prefix: "BRK", description: "Brake ECU") }

    it "shows project details" do
      visit project_path(project)
      expect(page).to have_content("Brake Controller")
      expect(page).to have_content("BRK")
      expect(page).to have_content("Brake ECU")
    end

    it "shows breadcrumb navigation" do
      visit project_path(project)
      expect(page).to have_link("Projects", href: projects_path)
      expect(page).to have_content("Brake Controller")
    end

    it "shows quick navigation cards" do
      visit project_path(project)
      expect(page).to have_content("Modules")
      expect(page).to have_content("Requirements")
      expect(page).to have_content("Links")
      expect(page).to have_content("Open Changes")
      expect(page).to have_content("Test Cases")
      expect(page).to have_content("Compliance")
    end

    it "shows requirements breakdown section" do
      visit project_path(project)
      expect(page).to have_content("Requirements Breakdown")
    end

    it "shows traceability health section" do
      visit project_path(project)
      expect(page).to have_content("Traceability Health")
      expect(page).to have_content("Forward links")
      expect(page).to have_content("Backward links")
      expect(page).to have_content("Test coverage")
    end

    it "shows ASIL coverage section" do
      visit project_path(project)
      expect(page).to have_content("ASIL Coverage")
    end

    it "shows change set velocity" do
      visit project_path(project)
      expect(page).to have_content("Change Sets")
      expect(page).to have_content("Open")
      expect(page).to have_content("Merged")
    end

    it "shows quick action buttons" do
      visit project_path(project)
      expect(page).to have_link("Quick Entry")
      expect(page).to have_link("New Requirement")
      expect(page).to have_link("New Change Set")
      expect(page).to have_link("Import / Export")
    end

    it "shows empty state for modules" do
      visit project_path(project)
      expect(page).to have_content("No modules yet")
    end

    it "shows modules and sections tree" do
      mod = create(:requirement_module, project: project, name: "System Requirements")
      create(:section, requirement_module: mod, name: "Functional Requirements")
      create(:section, requirement_module: mod, name: "Safety Requirements")
      visit project_path(project)
      expect(page).to have_content("System Requirements")
      expect(page).to have_content("Functional Requirements")
      expect(page).to have_content("Safety Requirements")
      expect(page).to have_content("2 sections")
    end

    it "shows edit and delete buttons for admin" do
      visit project_path(project)
      expect(page).to have_link("Edit")
      expect(page).to have_button("Delete")
    end

    it "navigates from index to project show" do
      visit projects_path
      click_link "Brake Controller"
      expect(page).to have_content("Brake Controller")
      expect(page).to have_content("Modules")
    end
  end

  describe "editing a project" do
    let!(:project) { create(:project, organization: organization, name: "Old Name", prefix: "OLD") }

    it "updates the project name" do
      visit edit_project_path(project)
      fill_in "Name", with: "New Name"
      click_button "Update Project"

      expect(page).to have_content("Project updated successfully")
      expect(page).to have_content("New Name")
    end

    it "shows the status selector on edit" do
      visit edit_project_path(project)
      expect(page).to have_select("Status")
    end

    it "can change project status to archived" do
      visit edit_project_path(project)
      select "Archived", from: "Status"
      click_button "Update Project"

      expect(page).to have_content("Project updated successfully")
      expect(page).to have_content("Archived")
    end

    it "shows validation errors on invalid update" do
      visit edit_project_path(project)
      fill_in "Name", with: ""
      click_button "Update Project"

      expect(page).to have_content("error")
    end

    it "can cancel and return to the project page" do
      visit edit_project_path(project)
      click_link "Cancel"
      expect(page).to have_current_path(project_path(project))
    end

    it "navigates from show to edit via edit button" do
      visit project_path(project)
      click_link "Edit"
      expect(page).to have_content("Edit Project")
      expect(page).to have_button("Update Project")
    end
  end

  describe "deleting a project" do
    let!(:project) { create(:project, organization: organization, name: "Doomed Project", prefix: "DOOM") }

    it "deletes the project and redirects to index" do
      visit project_path(project)
      click_button "Delete"

      expect(page).to have_content("Project deleted successfully")
      expect(page).to have_current_path(projects_path)
      expect(page).not_to have_content("Doomed Project")
    end
  end

  describe "complete project CRUD flow" do
    it "walks through create → view → edit → delete" do
      # Create
      visit projects_path
      click_link "New Project", match: :first
      fill_in "Name", with: "Full Flow Project"
      fill_in "Prefix", with: "FFP"
      fill_in "Description", with: "Testing the full CRUD flow"
      click_button "Create Project"

      expect(page).to have_content("Project created successfully")
      expect(page).to have_content("Full Flow Project")
      expect(page).to have_content("FFP")

      # View
      expect(page).to have_content("Modules")
      expect(page).to have_content("Requirements")
      expect(page).to have_content("No modules yet")

      # Edit
      click_link "Edit"
      fill_in "Name", with: "Renamed Flow Project"
      select "Archived", from: "Status"
      click_button "Update Project"

      expect(page).to have_content("Project updated successfully")
      expect(page).to have_content("Renamed Flow Project")
      expect(page).to have_content("Archived")

      # Delete
      click_button "Delete"
      expect(page).to have_content("Project deleted successfully")
      expect(page).to have_current_path(projects_path)
      expect(page).not_to have_content("Renamed Flow Project")
    end
  end

  describe "authorization" do
    context "when user is a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }
      let!(:project) { create(:project, organization: organization, name: "View Only", prefix: "VO") }

      it "can view projects index" do
        visit projects_path
        expect(page).to have_content("View Only")
      end

      it "can view project details" do
        visit project_path(project)
        expect(page).to have_content("View Only")
      end

      it "is redirected when trying to create a project" do
        visit new_project_path
        expect(page).to have_current_path(root_path)
      end

      it "is redirected when trying to edit a project" do
        visit edit_project_path(project)
        expect(page).to have_current_path(root_path)
      end
    end

    context "when user is a project manager" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :project_manager) }

      it "can create projects" do
        visit new_project_path
        fill_in "Name", with: "PM Project"
        fill_in "Prefix", with: "PMP"
        click_button "Create Project"
        expect(page).to have_content("Project created successfully")
      end

      it "can edit projects" do
        project = create(:project, organization: organization, name: "Editable", prefix: "EDT")
        visit edit_project_path(project)
        fill_in "Name", with: "Edited by PM"
        click_button "Update Project"
        expect(page).to have_content("Project updated successfully")
      end
    end
  end
end
