require "rails_helper"

RSpec.describe "Import / Export", type: :system do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization, prefix: "SYS") }

  before { sign_in user }

  describe "import/export page" do
    it "shows the page with export and import sections" do
      visit project_import_export_path(project)
      expect(page).to have_content("Import / Export")
      expect(page).to have_content("Export")
      expect(page).to have_content("Import")
    end

    it "shows breadcrumbs" do
      visit project_import_export_path(project)
      expect(page).to have_link("Projects", href: projects_path)
      expect(page).to have_link(project.name, href: project_path(project))
      expect(page).to have_content("Import / Export")
    end

    it "shows CSV export option with requirement count" do
      section = create(:section, requirement_module: create(:requirement_module, project: project))
      create_list(:requirement, 2, project: project, section: section, created_by: user)
      visit project_import_export_path(project)
      expect(page).to have_content("CSV Export")
      expect(page).to have_link("Download CSV")
      expect(page).to have_content("2 requirements")
    end

    it "shows ReqIF export option" do
      visit project_import_export_path(project)
      expect(page).to have_content("ReqIF Export")
      expect(page).to have_link("Download ReqIF")
      expect(page).to have_content("Requirements Interchange Format 1.2")
    end

    it "shows CSV import form" do
      visit project_import_export_path(project)
      expect(page).to have_content("CSV Import")
      expect(page).to have_button("Import CSV")
    end

    it "shows ReqIF import form" do
      visit project_import_export_path(project)
      expect(page).to have_content("ReqIF Import")
      expect(page).to have_button("Import ReqIF")
    end

    it "shows CSV format reference" do
      visit project_import_export_path(project)
      expect(page).to have_content("CSV Format Reference")
      expect(page).to have_content("Supported Columns")
      expect(page).to have_content("title")
      expect(page).to have_content("Required")
    end

    it "shows the project prefix badge" do
      visit project_import_export_path(project)
      expect(page).to have_content("SYS")
    end
  end

  describe "navigation" do
    it "links from project show page to import/export" do
      visit project_path(project)
      click_link "Import / Export"
      expect(page).to have_current_path(project_import_export_path(project))
    end

    it "links from sidebar to import/export" do
      visit project_import_export_path(project)
      within("nav.flex.flex-col") do
        expect(page).to have_link("Import / Export")
      end
    end
  end

  describe "role-based access" do
    context "as a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "shows export buttons but hides import forms" do
        visit project_import_export_path(project)
        expect(page).to have_link("Download CSV")
        expect(page).to have_link("Download ReqIF")
        expect(page).to have_content("Import not available")
        expect(page).not_to have_button("Import CSV")
        expect(page).not_to have_button("Import ReqIF")
      end
    end
  end

  describe "organization isolation" do
    let(:other_org) { create(:organization) }
    let(:other_project) { create(:project, organization: other_org) }

    it "cannot access another organization's import/export page" do
      visit project_import_export_path(other_project)
      expect(page).to have_content("Not Found").or have_content("not authorized")
    end
  end
end
