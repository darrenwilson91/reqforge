require "rails_helper"

RSpec.describe "Bulk Edit", type: :system do
  let(:organization) { create(:organization, name: "Acme Automotive") }
  let(:user) { create(:user, first_name: "Jane", last_name: "Engineer") }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization, name: "Brake System", prefix: "BRK") }
  let(:req_module) { create(:requirement_module, project: project, name: "System Requirements") }
  let(:section) { create(:section, requirement_module: req_module, name: "Functional Safety") }

  before { sign_in user }

  describe "bulk edit page rendering" do
    it "shows the bulk edit page with project name" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_content("Bulk Edit")
      expect(page).to have_content("Brake System")
    end

    it "shows breadcrumbs" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_link("Projects", href: projects_path)
      expect(page).to have_link("Brake System", href: project_path(project))
      expect(page).to have_link("Requirements", href: project_requirements_path(project))
      expect(page).to have_content("Bulk Edit")
    end

    it "shows Back to List button" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_link("Back to List", href: project_requirements_path(project))
    end

    it "shows empty state when no requirements exist" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_content("No requirements to edit")
      expect(page).to have_content("Create some requirements first")
    end

    it "shows Quick Entry link in empty state" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_link(href: quick_entry_project_requirements_path(project))
    end
  end

  describe "bulk edit with requirements" do
    let!(:req1) { create(:requirement, project: project, section: section, title: "Brake force requirement", created_by: user) }
    let!(:req2) { create(:requirement, project: project, section: section, title: "Pedal travel limit", created_by: user) }
    let!(:req3) { create(:requirement, project: project, section: section, title: "ABS activation threshold", created_by: user) }

    it "shows requirement count" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_content("3 requirements")
    end

    it "shows requirement UIDs in the table" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_content(req1.uid)
      expect(page).to have_content(req2.uid)
      expect(page).to have_content(req3.uid)
    end

    it "shows requirement titles in the table" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_content("Brake force requirement")
      expect(page).to have_content("Pedal travel limit")
      expect(page).to have_content("ABS activation threshold")
    end

    it "shows UID links to requirement detail pages" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_link(req1.uid, href: project_requirement_path(project, req1))
    end

    it "shows column headers" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_content("UID")
      expect(page).to have_content("Title")
      expect(page).to have_content("Type")
      expect(page).to have_content("Status")
      expect(page).to have_content("Priority")
      expect(page).to have_content("ASIL")
      expect(page).to have_content("Section")
    end

    it "shows select-all checkbox" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_css("input[type='checkbox'][data-bulk-edit-target='selectAll']")
    end

    it "shows per-row checkboxes" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_css("tr[data-requirement-id] input[type='checkbox']", count: 3)
    end

    it "shows module and section names" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_content("System Requirements / Functional Safety")
    end

    it "shows Save Changes and Cancel buttons" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_button("Save Changes")
      expect(page).to have_link("Cancel", href: project_requirements_path(project))
    end

    it "shows usage hints in save bar" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_content("Click any cell to edit inline")
      expect(page).to have_content("Tab to move between cells")
      expect(page).to have_content("Select rows for bulk actions")
    end
  end

  describe "editable cells" do
    let!(:req1) { create(:requirement, project: project, section: section, title: "Brake force requirement", requirement_type: :functional, status: :draft, priority: :must_have, asil_level: :asil_d, created_by: user) }

    it "has editable title cell with data attributes" do
      visit bulk_edit_project_requirements_path(project)
      cell = find("td[data-field='title']")
      expect(cell["data-field-type"]).to eq("text")
      expect(cell["data-value"]).to eq("Brake force requirement")
      expect(cell["data-action"]).to include("bulk-edit#editCell")
    end

    it "has editable type cell with data attributes" do
      visit bulk_edit_project_requirements_path(project)
      cell = find("td[data-field='requirement_type']")
      expect(cell["data-field-type"]).to eq("select")
      expect(cell["data-value"]).to eq("functional")
      expect(cell["data-action"]).to include("bulk-edit#editCell")
    end

    it "has editable status cell with data attributes" do
      visit bulk_edit_project_requirements_path(project)
      cell = find("td[data-field='status']")
      expect(cell["data-field-type"]).to eq("select")
      expect(cell["data-value"]).to eq("draft")
    end

    it "has editable priority cell with data attributes" do
      visit bulk_edit_project_requirements_path(project)
      cell = find("td[data-field='priority']")
      expect(cell["data-field-type"]).to eq("select")
      expect(cell["data-value"]).to eq("must_have")
    end

    it "has editable ASIL cell with data attributes" do
      visit bulk_edit_project_requirements_path(project)
      cell = find("td[data-field='asil_level']")
      expect(cell["data-field-type"]).to eq("select")
      expect(cell["data-value"]).to eq("asil_d")
    end

    it "has editable section cell with data attributes" do
      visit bulk_edit_project_requirements_path(project)
      cell = find("td[data-field='section_id']")
      expect(cell["data-field-type"]).to eq("select")
      expect(cell["data-value"]).to eq(section.id.to_s)
    end

    it "stores type options as JSON in data attribute" do
      visit bulk_edit_project_requirements_path(project)
      cell = find("td[data-field='requirement_type']")
      options = JSON.parse(cell["data-options"])
      expect(options.map(&:last)).to include("functional", "non_functional", "safety", "interface", "design_constraint")
    end

    it "stores ASIL options as JSON in data attribute" do
      visit bulk_edit_project_requirements_path(project)
      cell = find("td[data-field='asil_level']")
      options = JSON.parse(cell["data-options"])
      expect(options.map(&:last)).to include("qm", "asil_a", "asil_b", "asil_c", "asil_d")
    end
  end

  describe "hidden inputs for form submission" do
    let!(:req1) { create(:requirement, project: project, section: section, title: "Brake force", requirement_type: :safety, priority: :must_have, asil_level: :asil_d, created_by: user) }

    it "has hidden inputs for each editable field" do
      visit bulk_edit_project_requirements_path(project)

      expect(page).to have_css("input[type='hidden'][name='requirements[#{req1.id}][title]'][value='Brake force']", visible: false)
      expect(page).to have_css("input[type='hidden'][name='requirements[#{req1.id}][requirement_type]'][value='safety']", visible: false)
      expect(page).to have_css("input[type='hidden'][name='requirements[#{req1.id}][priority]'][value='must_have']", visible: false)
      expect(page).to have_css("input[type='hidden'][name='requirements[#{req1.id}][asil_level]'][value='asil_d']", visible: false)
      expect(page).to have_css("input[type='hidden'][name='requirements[#{req1.id}][section_id]'][value='#{section.id}']", visible: false)
    end
  end

  describe "bulk action toolbar" do
    let!(:req1) { create(:requirement, project: project, section: section, title: "Requirement One", created_by: user) }

    it "has toolbar element with hidden class by default" do
      visit bulk_edit_project_requirements_path(project)
      toolbar = find("[data-bulk-edit-target='toolbar']", visible: false)
      expect(toolbar[:class]).to include("hidden")
    end

    it "has Set Type bulk action button" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_button("Set Type")
    end

    it "has Set Priority bulk action button" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_button("Set Priority")
    end

    it "has Set ASIL bulk action button" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_button("Set ASIL")
    end

    it "has Move to Section bulk action button" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_button("Move to Section")
    end

    it "has Delete Selected bulk action button" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_button("Delete Selected")
    end

    it "has selected count display" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_css("[data-bulk-edit-target='selectedCount']", visible: false, text: "0 selected")
    end

    it "has type popover with select and apply button" do
      visit bulk_edit_project_requirements_path(project)
      popover = find("[data-popover='type']", visible: false)
      expect(popover).to have_css("select")
      expect(popover).to have_button("Apply")
    end

    it "has priority popover with select and apply button" do
      visit bulk_edit_project_requirements_path(project)
      popover = find("[data-popover='priority']", visible: false)
      expect(popover).to have_css("select")
      expect(popover).to have_button("Apply")
    end

    it "has ASIL popover with select and apply button" do
      visit bulk_edit_project_requirements_path(project)
      popover = find("[data-popover='asil']", visible: false)
      expect(popover).to have_css("select")
      expect(popover).to have_button("Apply")
    end

    it "has section popover with select and apply button" do
      visit bulk_edit_project_requirements_path(project)
      popover = find("[data-popover='section']", visible: false)
      expect(popover).to have_css("select")
      expect(popover).to have_button("Apply")
    end
  end

  describe "Stimulus controller wiring" do
    let!(:req1) { create(:requirement, project: project, section: section, title: "Test req", created_by: user) }

    it "has bulk-edit controller attached to the form" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_css("form[data-controller='bulk-edit']")
    end

    it "has bulk delete URL in data attribute" do
      visit bulk_edit_project_requirements_path(project)
      form = find("form[data-controller='bulk-edit']")
      expect(form["data-bulk-delete-url"]).to eq(bulk_delete_project_requirements_path(project))
    end

    it "has selectAll target on header checkbox" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_css("input[data-bulk-edit-target='selectAll']")
    end

    it "has row targets on table rows" do
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_css("tr[data-bulk-edit-target='row']", count: 1)
    end

    it "has cell targets on editable cells" do
      visit bulk_edit_project_requirements_path(project)
      # title, type, status, priority, asil, section = 6 cells per row
      expect(page).to have_css("td[data-bulk-edit-target='cell']", count: 6)
    end

    it "has toggleAll action on header checkbox" do
      visit bulk_edit_project_requirements_path(project)
      checkbox = find("input[data-bulk-edit-target='selectAll']")
      expect(checkbox["data-action"]).to include("bulk-edit#toggleAll")
    end

    it "has toggleRow action on row checkboxes" do
      visit bulk_edit_project_requirements_path(project)
      checkbox = find("tr[data-bulk-edit-target='row'] input[type='checkbox']")
      expect(checkbox["data-action"]).to include("bulk-edit#toggleRow")
    end

    it "has editCell action on editable cells" do
      visit bulk_edit_project_requirements_path(project)
      cells = all("td[data-bulk-edit-target='cell']")
      cells.each do |cell|
        expect(cell["data-action"]).to include("bulk-edit#editCell")
      end
    end
  end

  describe "server-side form submission" do
    let!(:req1) { create(:requirement, project: project, section: section, title: "Original Title", requirement_type: :functional, priority: :must_have, asil_level: :qm, created_by: user) }

    it "saves title changes via form submission" do
      visit bulk_edit_project_requirements_path(project)

      # Directly update the hidden input value to simulate JS edit
      find("input[name='requirements[#{req1.id}][title]']", visible: false).set("Updated Title")
      click_button "Save Changes"

      expect(page).to have_content("1 requirement updated.")
      req1.reload
      expect(req1.title).to eq("Updated Title")
    end

    it "saves type changes via form submission" do
      visit bulk_edit_project_requirements_path(project)

      find("input[name='requirements[#{req1.id}][requirement_type]']", visible: false).set("safety")
      click_button "Save Changes"

      req1.reload
      expect(req1.requirement_type).to eq("safety")
    end

    it "saves priority changes via form submission" do
      visit bulk_edit_project_requirements_path(project)

      find("input[name='requirements[#{req1.id}][priority]']", visible: false).set("could_have")
      click_button "Save Changes"

      req1.reload
      expect(req1.priority).to eq("could_have")
    end

    it "saves ASIL level changes via form submission" do
      visit bulk_edit_project_requirements_path(project)

      find("input[name='requirements[#{req1.id}][asil_level]']", visible: false).set("asil_d")
      click_button "Save Changes"

      req1.reload
      expect(req1.asil_level).to eq("asil_d")
    end

    it "saves multiple attribute changes at once" do
      visit bulk_edit_project_requirements_path(project)

      find("input[name='requirements[#{req1.id}][title]']", visible: false).set("New Title")
      find("input[name='requirements[#{req1.id}][requirement_type]']", visible: false).set("safety")
      find("input[name='requirements[#{req1.id}][asil_level]']", visible: false).set("asil_c")
      click_button "Save Changes"

      req1.reload
      expect(req1.title).to eq("New Title")
      expect(req1.requirement_type).to eq("safety")
      expect(req1.asil_level).to eq("asil_c")
    end

    it "redirects back to bulk edit after save" do
      visit bulk_edit_project_requirements_path(project)
      click_button "Save Changes"

      expect(page).to have_current_path(bulk_edit_project_requirements_path(project))
    end

    it "cancel navigates back to requirements index" do
      visit bulk_edit_project_requirements_path(project)
      click_link "Cancel"

      expect(page).to have_current_path(project_requirements_path(project))
    end
  end

  describe "multiple requirements editing" do
    let!(:req1) { create(:requirement, project: project, section: section, title: "First", requirement_type: :functional, created_by: user) }
    let!(:req2) { create(:requirement, project: project, section: section, title: "Second", requirement_type: :functional, created_by: user) }

    it "saves changes to multiple requirements" do
      visit bulk_edit_project_requirements_path(project)

      find("input[name='requirements[#{req1.id}][requirement_type]']", visible: false).set("safety")
      find("input[name='requirements[#{req2.id}][requirement_type]']", visible: false).set("interface")
      click_button "Save Changes"

      expect(page).to have_content("2 requirements updated.")
      expect(req1.reload.requirement_type).to eq("safety")
      expect(req2.reload.requirement_type).to eq("interface")
    end
  end

  describe "section move via form" do
    let(:section2) { create(:section, requirement_module: req_module, name: "Performance") }
    let!(:req1) { create(:requirement, project: project, section: section, title: "Movable req", created_by: user) }

    it "moves requirement to a different section" do
      section2 # ensure created
      visit bulk_edit_project_requirements_path(project)

      find("input[name='requirements[#{req1.id}][section_id]']", visible: false).set(section2.id.to_s)
      click_button "Save Changes"

      req1.reload
      expect(req1.section_id).to eq(section2.id)
    end
  end

  describe "navigation" do
    it "has Bulk Edit button on requirements index page" do
      visit project_requirements_path(project)
      expect(page).to have_link("Bulk Edit", href: bulk_edit_project_requirements_path(project))
    end

    it "navigates from requirements index to bulk edit" do
      visit project_requirements_path(project)
      click_link "Bulk Edit"
      expect(page).to have_current_path(bulk_edit_project_requirements_path(project))
      expect(page).to have_content("Bulk Edit")
    end

    it "navigates from bulk edit back to requirements index" do
      visit bulk_edit_project_requirements_path(project)
      click_link "Back to List"
      expect(page).to have_current_path(project_requirements_path(project))
    end
  end

  describe "role-based access" do
    it "denies access for viewers" do
      membership.update!(role: :viewer)
      visit bulk_edit_project_requirements_path(project)
      expect(page).not_to have_content("Bulk Edit")
    end

    it "denies access for authors" do
      membership.update!(role: :author)
      visit bulk_edit_project_requirements_path(project)
      expect(page).not_to have_content("Bulk Edit")
    end

    it "allows access for project managers" do
      membership.update!(role: :project_manager)
      visit bulk_edit_project_requirements_path(project)
      expect(page).to have_content("Bulk Edit")
    end
  end

  describe "organization isolation" do
    let(:other_org) { create(:organization) }
    let(:other_project) { create(:project, organization: other_org) }
    let(:other_module) { create(:requirement_module, project: other_project) }
    let(:other_section) { create(:section, requirement_module: other_module) }
    let!(:other_req) { create(:requirement, project: other_project, section: other_section, title: "Other org req", created_by: user) }

    it "does not show requirements from other organizations" do
      create(:requirement, project: project, section: section, title: "My org req", created_by: user)
      visit bulk_edit_project_requirements_path(project)

      expect(page).to have_content("My org req")
      expect(page).not_to have_content("Other org req")
    end
  end

  describe "data-requirement-id on rows" do
    let!(:req1) { create(:requirement, project: project, section: section, title: "Row ID test", created_by: user) }

    it "sets data-requirement-id on each row" do
      visit bulk_edit_project_requirements_path(project)
      row = find("tr[data-requirement-id='#{req1.id}']")
      expect(row).to be_present
    end
  end

  describe "section options in popovers" do
    let(:section2) { create(:section, requirement_module: req_module, name: "Performance") }
    let!(:req1) { create(:requirement, project: project, section: section, title: "Test", created_by: user) }

    it "lists available sections in section popover" do
      section2 # create
      visit bulk_edit_project_requirements_path(project)
      popover = find("[data-popover='section']", visible: false)
      options_html = popover.find("select", visible: false).native.inner_html
      expect(options_html).to include("Functional Safety")
      expect(options_html).to include("Performance")
    end
  end

  describe "complete bulk edit flow" do
    let!(:req1) { create(:requirement, project: project, section: section, title: "Flow req 1", requirement_type: :functional, priority: :must_have, asil_level: :qm, created_by: user) }
    let!(:req2) { create(:requirement, project: project, section: section, title: "Flow req 2", requirement_type: :functional, priority: :must_have, asil_level: :qm, created_by: user) }

    it "completes a full edit flow: navigate, edit, save, verify" do
      # Navigate from index
      visit project_requirements_path(project)
      click_link "Bulk Edit"
      expect(page).to have_content("Bulk Edit")
      expect(page).to have_content("2 requirements")

      # Edit attributes via hidden inputs
      find("input[name='requirements[#{req1.id}][requirement_type]']", visible: false).set("safety")
      find("input[name='requirements[#{req1.id}][asil_level]']", visible: false).set("asil_d")
      find("input[name='requirements[#{req2.id}][priority]']", visible: false).set("could_have")

      # Save
      click_button "Save Changes"

      # Verify redirect and flash
      expect(page).to have_current_path(bulk_edit_project_requirements_path(project))
      expect(page).to have_content("2 requirements updated.")

      # Verify persistence
      expect(req1.reload.requirement_type).to eq("safety")
      expect(req1.asil_level).to eq("asil_d")
      expect(req2.reload.priority).to eq("could_have")
    end
  end
end
