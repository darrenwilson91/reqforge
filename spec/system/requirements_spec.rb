require "rails_helper"

RSpec.describe "Requirements Management", type: :system do
  let(:organization) { create(:organization, name: "Acme Automotive") }
  let(:user) { create(:user, first_name: "Jane", last_name: "Engineer") }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization, name: "Brake System", prefix: "BRK") }
  let(:req_module) { create(:requirement_module, project: project, name: "System Requirements") }
  let(:section) { create(:section, requirement_module: req_module, name: "Functional Safety") }

  before { sign_in user }

  describe "requirements index page" do
    it "shows empty state when no requirements exist" do
      visit project_requirements_path(project)
      expect(page).to have_content("No requirements yet")
      expect(page).to have_link("New Requirement")
    end

    it "lists requirements in a table" do
      req = create(:requirement, project: project, section: section, created_by: user,
                   title: "ABS shall prevent wheel lock", requirement_type: :safety, asil_level: :asil_d)
      visit project_requirements_path(project)
      expect(page).to have_content(req.uid)
      expect(page).to have_content("ABS shall prevent wheel lock")
      expect(page).to have_content("Safety")
      expect(page).to have_content("ASIL D")
    end

    it "shows the hierarchy tree panel" do
      create(:requirement, project: project, section: section, created_by: user, title: "Tree Req")
      visit project_requirements_path(project)
      expect(page).to have_content("System Requirements")
      expect(page).to have_content("Functional Safety")
    end

    it "does not show requirements from other organizations" do
      other_org = create(:organization)
      other_project = create(:project, organization: other_org)
      other_section = create(:section, requirement_module: create(:requirement_module, project: other_project))
      create(:requirement, project: other_project, section: other_section, created_by: user, title: "Secret Req")

      visit project_requirements_path(project)
      expect(page).not_to have_content("Secret Req")
    end
  end

  describe "creating a requirement" do
    before do
      # Ensure module/section exist for the form dropdown
      section
    end

    it "creates a requirement with valid data" do
      visit new_project_requirement_path(project)
      expect(page).to have_content("New Requirement")
      expect(page).to have_content(project.name)

      fill_in "Title", with: "The braking system shall achieve full stop within 50m"
      select "System Requirements > Functional Safety", from: "Module / Section"
      select "Safety", from: "Type"
      select "Must have", from: "Priority"
      select "ASIL D", from: "ASIL Level"
      click_button "Create Requirement"

      expect(page).to have_content("Requirement created successfully")
      expect(page).to have_content("The braking system shall achieve full stop within 50m")
      expect(page).to have_content("BRK-0001")
      expect(page).to have_content("Safety")
      expect(page).to have_content("ASIL D")
    end

    it "shows validation errors for blank title" do
      visit new_project_requirement_path(project)
      fill_in "Title", with: ""
      click_button "Create Requirement"

      expect(page).to have_content("Please fix the following errors")
      expect(page).to have_content("Title can't be blank")
    end

    it "navigates from index to new form" do
      visit project_requirements_path(project)
      click_link "New Requirement", match: :first
      expect(page).to have_content("Add a new requirement")
    end

    it "cancels creation and returns to index" do
      visit new_project_requirement_path(project)
      click_link "Cancel"
      expect(page).to have_current_path(project_requirements_path(project))
    end
  end

  describe "viewing a requirement" do
    let!(:requirement) do
      create(:requirement, project: project, section: section, created_by: user,
             title: "ABS shall prevent wheel lock during braking",
             body: "The anti-lock braking system shall prevent any wheel from locking during emergency braking.",
             requirement_type: :safety, status: :draft, priority: :must_have, asil_level: :asil_d)
    end

    it "shows all requirement details" do
      visit project_requirement_path(project, requirement)
      expect(page).to have_content(requirement.uid)
      expect(page).to have_content("ABS shall prevent wheel lock during braking")
      expect(page).to have_content("anti-lock braking system")
      expect(page).to have_content("Safety")
      expect(page).to have_content("Draft")
      expect(page).to have_content("Must have")
      expect(page).to have_content("ASIL D")
    end

    it "shows breadcrumb navigation" do
      visit project_requirement_path(project, requirement)
      expect(page).to have_link("Projects")
      expect(page).to have_link("Brake System")
      expect(page).to have_link("Requirements")
      expect(page).to have_content(requirement.uid)
    end

    it "shows module and section in metadata" do
      visit project_requirement_path(project, requirement)
      expect(page).to have_content("System Requirements")
      expect(page).to have_content("Functional Safety")
    end

    it "shows the creator name" do
      visit project_requirement_path(project, requirement)
      expect(page).to have_content("Jane Engineer")
    end

    it "shows the hierarchy tree with the active requirement highlighted" do
      visit project_requirement_path(project, requirement)
      expect(page).to have_content("System Requirements")
      expect(page).to have_content("Functional Safety")
      expect(page).to have_content(requirement.uid)
    end

    it "shows version history with create event" do
      visit project_requirement_path(project, requirement)
      expect(page).to have_content("Version History")
      expect(page).to have_content("1 revision")
    end

    it "shows custom attributes when present" do
      requirement.update!(custom_attributes: { "Verification Method" => "Test", "Safety Classification" => "ASIL-D" })
      visit project_requirement_path(project, requirement)
      expect(page).to have_content("Verification Method")
      expect(page).to have_content("Test")
      expect(page).to have_content("Safety Classification")
      expect(page).to have_content("ASIL-D")
    end

    it "shows traceability links section" do
      visit project_requirement_path(project, requirement)
      expect(page).to have_content("Traceability Links")
    end

    it "displays status workflow with transition buttons" do
      visit project_requirement_path(project, requirement)
      expect(page).to have_content("Submit for Review")
      expect(page).to have_content("Mark Obsolete")
    end
  end

  describe "editing a requirement" do
    let!(:requirement) do
      create(:requirement, project: project, section: section, created_by: user,
             title: "Original Title", body: "Original body text")
    end

    it "updates the requirement title" do
      visit edit_project_requirement_path(project, requirement)
      fill_in "Title", with: "Updated Brake Requirement"
      click_button "Update Requirement"

      expect(page).to have_content("Requirement updated successfully")
      expect(page).to have_content("Updated Brake Requirement")
    end

    it "shows validation errors on invalid update" do
      visit edit_project_requirement_path(project, requirement)
      fill_in "Title", with: ""
      click_button "Update Requirement"

      expect(page).to have_content("Please fix the following errors")
      expect(page).to have_content("Title can't be blank")
    end

    it "cancels editing and returns to detail view" do
      visit edit_project_requirement_path(project, requirement)
      click_link "Cancel"
      expect(page).to have_current_path(project_requirement_path(project, requirement))
    end

    it "preserves the UID when editing" do
      original_uid = requirement.uid
      visit edit_project_requirement_path(project, requirement)
      fill_in "Title", with: "Changed Title"
      click_button "Update Requirement"
      expect(page).to have_content(original_uid)
    end
  end

  describe "deleting a requirement" do
    let!(:requirement) do
      create(:requirement, project: project, section: section, created_by: user,
             title: "Requirement to Delete")
    end

    it "deletes the requirement from the show page" do
      visit project_requirement_path(project, requirement)
      expect(page).to have_button("Delete")
    end
  end

  describe "status transitions" do
    let!(:requirement) do
      create(:requirement, project: project, section: section, created_by: user,
             title: "Status Test Req", status: :draft)
    end

    it "transitions from draft to in_review" do
      visit project_requirement_path(project, requirement)
      click_button "Submit for Review"
      expect(page).to have_content("Status changed to In review")
      expect(page).to have_content("In review")
    end

    it "shows available transitions for in_review status" do
      requirement.update_column(:status, 1) # in_review
      visit project_requirement_path(project, requirement)
      expect(page).to have_button("Approve")
      expect(page).to have_button("Return to Draft")
    end

    it "shows available transitions for approved status" do
      requirement.update_column(:status, 2) # approved
      visit project_requirement_path(project, requirement)
      expect(page).to have_button("Mark Implemented")
      expect(page).to have_button("Re-open Review")
    end
  end

  describe "version history" do
    let!(:requirement) do
      create(:requirement, project: project, section: section, created_by: user,
             title: "Version History Test")
    end

    it "shows version count that increments on update" do
      requirement.update!(title: "Updated Title")
      visit project_requirement_path(project, requirement)
      expect(page).to have_content("2 revisions")
    end

    it "displays version entries with event types" do
      requirement.update!(title: "Updated Title")
      visit project_requirement_path(project, requirement)
      expect(page).to have_content("Update")
      expect(page).to have_content("Create")
    end
  end

  describe "complete CRUD flow" do
    before { section }

    it "creates, views, edits, and returns to index" do
      # Create
      visit new_project_requirement_path(project)

      fill_in "Title", with: "Complete flow requirement"
      select "System Requirements > Functional Safety", from: "Module / Section"
      click_button "Create Requirement"

      expect(page).to have_content("Requirement created successfully")
      expect(page).to have_content("Complete flow requirement")
      expect(page).to have_content("BRK-0001")

      # Edit via standalone page
      visit edit_project_requirement_path(project, Requirement.last)
      fill_in "Title", with: "Edited flow requirement"
      click_button "Update Requirement"

      expect(page).to have_content("Requirement updated successfully")
      expect(page).to have_content("Edited flow requirement")

      # Verify version history shows both create and update
      expect(page).to have_content("2 revisions")

      # Back to index via breadcrumb
      click_link "Requirements"
      expect(page).to have_content("Edited flow requirement")
    end
  end

  describe "role-based authorization" do
    context "viewer role" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "can view requirements but cannot see New Requirement button" do
        create(:requirement, project: project, section: section, created_by: create(:user), title: "Viewable Req")
        visit project_requirements_path(project)
        expect(page).to have_content("Viewable Req")
        expect(page).not_to have_link("New Requirement")
      end

      it "can view requirement details but cannot see Edit or Delete buttons" do
        req = create(:requirement, project: project, section: section, created_by: create(:user), title: "Read Only Req")
        visit project_requirement_path(project, req)
        expect(page).to have_content("Read Only Req")
        expect(page).not_to have_link("Edit")
        expect(page).not_to have_button("Delete")
      end
    end

    context "author role" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :author) }

      it "can create and edit requirements" do
        visit project_requirements_path(project)
        expect(page).to have_link("New Requirement")
      end

      it "can see Edit but not Delete on requirement detail" do
        req = create(:requirement, project: project, section: section, created_by: user, title: "Author Req")
        visit project_requirement_path(project, req)
        expect(page).to have_link("Edit")
        expect(page).not_to have_button("Delete")
      end
    end
  end
end
