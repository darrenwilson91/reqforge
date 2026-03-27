require "rails_helper"

RSpec.describe "Compliance Dashboard", type: :system do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization) }

  before { sign_in user }

  def create_module_with_reqs(name:, count:, asil: "qm")
    mod = create(:requirement_module, project: project, name: name)
    section = create(:section, requirement_module: mod, name: "Default")
    reqs = count.times.map do
      create(:requirement, project: project, section: section, created_by: user, asil_level: asil)
    end
    [ mod, section, reqs ]
  end

  describe "empty project" do
    it "shows empty states" do
      visit project_compliance_dashboard_path(project)
      expect(page).to have_content("Compliance Dashboard")
      expect(page).to have_content("No modules defined")
      expect(page).to have_content("No requirements yet")
    end

    it "shows no compliance template detected" do
      visit project_compliance_dashboard_path(project)
      expect(page).to have_content("No compliance template detected")
    end

    it "shows zero in summary cards" do
      visit project_compliance_dashboard_path(project)
      expect(page).to have_content("Requirements")
      expect(page).to have_content("Phases")
    end
  end

  describe "project with modules and requirements" do
    before do
      create_module_with_reqs(name: "System Requirements", count: 3, asil: "asil_c")
      create_module_with_reqs(name: "Software Requirements", count: 2, asil: "qm")
    end

    it "shows coverage by phase table" do
      visit project_compliance_dashboard_path(project)
      expect(page).to have_content("Coverage by Phase")
      expect(page).to have_content("System Requirements")
      expect(page).to have_content("Software Requirements")
    end

    it "shows ASIL distribution with correct levels" do
      visit project_compliance_dashboard_path(project)
      expect(page).to have_content("ASIL Distribution")
      expect(page).to have_content("ASIL C")
      expect(page).to have_content("QM")
    end

    it "shows safety-rated requirements callout" do
      visit project_compliance_dashboard_path(project)
      expect(page).to have_content("safety-rated requirement")
    end

    it "shows overall traceability coverage" do
      visit project_compliance_dashboard_path(project)
      expect(page).to have_content("Overall Traceability Coverage")
    end
  end

  describe "project with ISO 26262 template" do
    before do
      ComplianceTemplate.seed_templates!
      template = ComplianceTemplate.find_by(standard: "iso_26262")
      template.apply_to_project!(project)
    end

    it "shows detected template name" do
      visit project_compliance_dashboard_path(project)
      expect(page).to have_content("ISO 26262")
    end

    it "shows expected traceability links section" do
      visit project_compliance_dashboard_path(project)
      expect(page).to have_content("Expected Traceability Links")
    end

    it "shows all V-model phases" do
      visit project_compliance_dashboard_path(project)
      expect(page).to have_content("System Requirements")
      expect(page).to have_content("Software Requirements")
      expect(page).to have_content("Software Architecture")
      expect(page).to have_content("Unit Test Specifications")
    end
  end

  describe "breadcrumbs and navigation" do
    it "shows breadcrumbs linking to projects and project" do
      visit project_compliance_dashboard_path(project)
      expect(page).to have_link("Projects", href: projects_path)
      expect(page).to have_link(project.name, href: project_path(project))
    end

    it "has navigation links to matrix and requirements" do
      visit project_compliance_dashboard_path(project)
      expect(page).to have_link("Matrix", href: project_traceability_matrix_path(project))
      expect(page).to have_link("Requirements", href: project_requirements_path(project))
    end
  end

  describe "navigation from project show page" do
    it "links to compliance dashboard from project show" do
      visit project_path(project)
      expect(page).to have_link(href: project_compliance_dashboard_path(project))
    end
  end

  describe "sidebar navigation" do
    it "shows Compliance link in sidebar when viewing a project" do
      visit project_compliance_dashboard_path(project)
      within("nav.flex.flex-col") do
        expect(page).to have_content("Compliance")
      end
    end
  end

  describe "role-based access" do
    it "allows viewer to see the dashboard" do
      membership.update!(role: :viewer)
      visit project_compliance_dashboard_path(project)
      expect(page).to have_content("Compliance Dashboard")
    end
  end

  describe "organization isolation" do
    let(:other_org) { create(:organization) }
    let(:other_project) { create(:project, organization: other_org) }

    it "does not show another organization's project" do
      visit project_compliance_dashboard_path(other_project)
      expect(page).to have_content("Not Found").or have_content("not authorized")
    end
  end
end
