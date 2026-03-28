require "rails_helper"

RSpec.describe "Quick Entry", type: :system do
  let(:organization) { create(:organization, name: "Acme Automotive") }
  let(:user) { create(:user, first_name: "Jane", last_name: "Engineer") }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization, name: "Brake System", prefix: "BRK") }
  let(:req_module) { create(:requirement_module, project: project, name: "System Requirements") }
  let(:section) { create(:section, requirement_module: req_module, name: "Functional Safety") }

  before { sign_in user }

  describe "quick entry page without section selected" do
    it "shows the quick entry page with project name and prefix" do
      visit quick_entry_project_requirements_path(project)
      expect(page).to have_content("Quick Entry")
      expect(page).to have_content("Brake System")
      expect(page).to have_content("BRK")
    end

    it "shows breadcrumbs" do
      visit quick_entry_project_requirements_path(project)
      expect(page).to have_link("Projects", href: projects_path)
      expect(page).to have_link("Brake System", href: project_path(project))
      expect(page).to have_link("Requirements", href: project_requirements_path(project))
      expect(page).to have_content("Quick Entry")
    end

    it "shows section selector dropdown with options" do
      section # create
      visit quick_entry_project_requirements_path(project)
      expect(page).to have_css("select[data-quick-entry-target='sectionSelect']")
      expect(page).to have_content("System Requirements")
      expect(page).to have_content("Functional Safety")
    end

    it "shows empty state prompting section selection" do
      visit quick_entry_project_requirements_path(project)
      expect(page).to have_content("Select a section to begin")
    end

    it "shows Back to List link" do
      visit quick_entry_project_requirements_path(project)
      expect(page).to have_link("Back to List", href: project_requirements_path(project))
    end

    it "shows Done button in floating action bar" do
      visit quick_entry_project_requirements_path(project)
      expect(page).to have_link("Done", href: project_requirements_path(project))
    end
  end

  describe "quick entry page with section selected" do
    it "shows the text input area" do
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_css("textarea[data-quick-entry-target='titleInput']")
      expect(page).to have_content("save & next")
      expect(page).to have_content("new line")
      expect(page).to have_content("set attributes")
    end

    it "shows keyboard hints" do
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_content("Enter")
      expect(page).to have_content("Shift+Enter")
      expect(page).to have_content("Tab")
      expect(page).to have_content("navigate rows")
      expect(page).to have_content("Backspace")
    end

    it "shows UID placeholder" do
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_content("BRK-????")
    end

    it "shows default attribute badges" do
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_content("Functional")
      expect(page).to have_content("Must Have")
      expect(page).to have_content("QM")
    end

    it "shows existing requirements in the section" do
      req = create(:requirement, project: project, section: section, created_by: user,
                   title: "ABS shall prevent wheel lock")
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_content(req.uid)
      expect(page).to have_content("ABS shall prevent wheel lock")
    end

    it "shows session counter at 0" do
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_css("[data-quick-entry-target='sessionCount']", text: "0")
      expect(page).to have_content("entered this session")
    end

    it "shows section total counter" do
      create(:requirement, project: project, section: section, created_by: user, title: "Req 1")
      create(:requirement, project: project, section: section, created_by: user, title: "Req 2")
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_css("[data-quick-entry-target='totalCount']", text: "2")
      expect(page).to have_content("in section")
    end

    it "does not show requirements from other sections" do
      other_section = create(:section, requirement_module: req_module, name: "Performance")
      create(:requirement, project: project, section: other_section, created_by: user,
             title: "Other section requirement")
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).not_to have_content("Other section requirement")
    end

    it "shows section switcher in action bar" do
      section # ensure exists
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_css("select[data-quick-entry-target='sectionSwitcher']")
    end

    it "links requirement UIDs to detail page" do
      req = create(:requirement, project: project, section: section, created_by: user,
                   title: "Linked requirement")
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_link(req.uid, href: project_requirement_path(project, req))
    end

    it "has attribute bar element in the DOM" do
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      # The attribute bar has the hidden class by default (CSS-hidden, not removed from DOM)
      expect(page).to have_css("[data-quick-entry-target='attributeBar']", visible: :all)
    end
  end

  describe "navigation to quick entry" do
    it "shows Quick Entry button on requirements index" do
      visit project_requirements_path(project)
      expect(page).to have_link("Quick Entry", href: quick_entry_project_requirements_path(project))
    end

    it "shows Quick Entry link on project show page" do
      visit project_path(project)
      expect(page).to have_link(href: quick_entry_project_requirements_path(project))
    end

    it "navigates from requirements index to quick entry" do
      section # create module/section
      visit project_requirements_path(project)
      click_link "Quick Entry"
      expect(page).to have_content("Quick Entry")
      expect(page).to have_content("Brake System")
    end
  end

  describe "quick entry with multiple modules and sections" do
    let(:mod2) { create(:requirement_module, project: project, name: "HW Requirements") }
    let(:section2) { create(:section, requirement_module: mod2, name: "Power Supply") }

    it "lists all sections in dropdown" do
      section  # System Requirements > Functional Safety
      section2 # HW Requirements > Power Supply
      visit quick_entry_project_requirements_path(project)
      expect(page).to have_content("System Requirements")
      expect(page).to have_content("Functional Safety")
      expect(page).to have_content("HW Requirements")
      expect(page).to have_content("Power Supply")
    end

    it "scopes requirements to selected section" do
      create(:requirement, project: project, section: section, created_by: user,
             title: "Safety req")
      create(:requirement, project: project, section: section2, created_by: user,
             title: "Power req")
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_content("Safety req")
      expect(page).not_to have_content("Power req")
    end
  end

  describe "quick entry with nested sections" do
    let(:parent_section) { create(:section, requirement_module: req_module, name: "Safety") }
    let!(:child_section) { create(:section, requirement_module: req_module, parent_section: parent_section, name: "Thermal Safety") }

    it "shows top-level sections in dropdown (child sections are nested under parents)" do
      visit quick_entry_project_requirements_path(project)
      # build_section_options only lists top-level sections
      expect(page).to have_content("System Requirements")
      expect(page).to have_content("Safety")
    end
  end

  describe "quick entry for different user roles" do
    it "allows viewers to access quick entry page" do
      viewer = create(:user, first_name: "View", last_name: "Only")
      create(:membership, user: viewer, organization: organization, role: :viewer)
      sign_in viewer
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_content("Quick Entry")
    end

    it "shows the page for authors" do
      author = create(:user, first_name: "Auth", last_name: "Or")
      create(:membership, user: author, organization: organization, role: :author)
      sign_in author
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_content("Quick Entry")
    end
  end

  describe "quick entry organization isolation" do
    it "does not show requirements from other organizations" do
      other_org = create(:organization, name: "Other Corp")
      other_project = create(:project, organization: other_org, name: "Secret Project", prefix: "SEC")
      other_module = create(:requirement_module, project: other_project)
      other_section = create(:section, requirement_module: other_module)
      create(:requirement, project: other_project, section: other_section, created_by: user,
             title: "Secret requirement")

      # Visit own project's quick entry — should not see other org's requirements
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).not_to have_content("Secret requirement")
      expect(page).not_to have_content("Secret Project")
    end
  end

  describe "quick entry requirement rows" do
    it "shows requirement type on hover area" do
      create(:requirement, project: project, section: section, created_by: user,
             title: "Test req", requirement_type: :safety)
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_content("Safety")
    end

    it "shows requirement status badge" do
      create(:requirement, project: project, section: section, created_by: user,
             title: "Approved req", status: :approved)
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_content("Approved")
    end

    it "displays requirements in position order" do
      create(:requirement, project: project, section: section, created_by: user,
             title: "First requirement", position: 1)
      create(:requirement, project: project, section: section, created_by: user,
             title: "Second requirement", position: 2)
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      body = page.body
      expect(body.index("First requirement")).to be < body.index("Second requirement")
    end

    it "has data-requirement-id on each row" do
      req = create(:requirement, project: project, section: section, created_by: user,
                   title: "Data attr req")
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_css("[data-requirement-id='#{req.id}']")
    end
  end

  describe "quick entry Stimulus controller wiring" do
    it "has the quick-entry controller on the wrapper div" do
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_css("[data-controller='quick-entry']")
    end

    it "has the correct URL value for creating requirements" do
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expected_url = quick_create_project_requirements_path(project)
      expect(page).to have_css("[data-quick-entry-url-value='#{expected_url}']")
    end

    it "has the correct delete URL value template with placeholder" do
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      wrapper = page.find("[data-controller='quick-entry']")
      expect(wrapper["data-quick-entry-delete-url-value"]).to include("__ID__")
    end

    it "has the section value set from params" do
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_css("[data-quick-entry-section-value='#{section.id}']")
    end

    it "has keydown action on textarea" do
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_css("textarea[data-action*='keydown->quick-entry#handleKeydown']")
    end

    it "has keydown action on requirement list for row navigation" do
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_css("[data-quick-entry-target='requirementList'][data-action*='keydown->quick-entry#handleRowKeydown']")
    end

    it "has keydown action on attribute bar" do
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      attribute_bar = page.find("[data-quick-entry-target='attributeBar']", visible: :all)
      expect(attribute_bar["data-action"]).to include("keydown->quick-entry#handleAttributeKeydown")
    end

    it "has change action on section selectors" do
      section # create
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_css("select[data-action*='change->quick-entry#changeSection']")
    end
  end

  describe "quick create via server-side simulation" do
    # These tests simulate what the JS keyboard handler does (POST to quick_create)
    # by creating requirements directly and verifying they appear on the quick entry page.

    it "newly created requirements appear on the quick entry page" do
      create(:requirement, project: project, section: section, created_by: user,
             title: "Quick entered requirement")
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_content("Quick entered requirement")
      expect(page).to have_css("[data-quick-entry-target='totalCount']", text: "1")
    end

    it "multiple requirements appear in order with correct count" do
      create(:requirement, project: project, section: section, created_by: user,
             title: "First quick req", position: 1)
      create(:requirement, project: project, section: section, created_by: user,
             title: "Second quick req", position: 2)
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_content("First quick req")
      expect(page).to have_content("Second quick req")
      expect(page).to have_css("[data-quick-entry-target='totalCount']", text: "2")
    end

    it "auto-generated UIDs use project prefix" do
      req = create(:requirement, project: project, section: section, created_by: user,
                   title: "Auto UID req")
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_content(req.uid)
      expect(req.uid).to start_with("BRK-")
    end

    it "requirements with custom attributes appear correctly" do
      create(:requirement, project: project, section: section, created_by: user,
             title: "Safety critical req", requirement_type: :safety, asil_level: :asil_d)
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_content("Safety critical req")
      expect(page).to have_content("Safety")
    end
  end

  describe "quick entry complete flow" do
    it "navigates from requirements index to quick entry and back" do
      section # create module/section
      create(:requirement, project: project, section: section, created_by: user,
             title: "Flow test requirement")

      # Start at requirements index
      visit project_requirements_path(project)
      expect(page).to have_link("Quick Entry")

      # Navigate to quick entry
      click_link "Quick Entry"
      expect(page).to have_content("Quick Entry")
      expect(page).to have_content("Brake System")

      # Visit with section selected (simulates section dropdown JS navigation)
      visit quick_entry_project_requirements_path(project, section_id: section.id)
      expect(page).to have_content("Flow test requirement")
      expect(page).to have_css("textarea[data-quick-entry-target='titleInput']")

      # Navigate back via Done
      click_link "Done"
      expect(current_path).to eq(project_requirements_path(project))
      expect(page).to have_content("Flow test requirement")
    end

    it "navigates back via Back to List link" do
      visit quick_entry_project_requirements_path(project)
      click_link "Back to List"
      expect(current_path).to eq(project_requirements_path(project))
    end
  end
end
