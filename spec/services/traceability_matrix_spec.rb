require "rails_helper"

RSpec.describe TraceabilityMatrix do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:project) { create(:project, organization: organization) }
  let(:mod) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: mod) }

  let(:req_a) { create(:requirement, section: section, project: project, created_by: user, title: "System shall boot in 5s") }
  let(:req_b) { create(:requirement, section: section, project: project, created_by: user, title: "SW shall initialize within 3s") }
  let(:req_c) { create(:requirement, section: section, project: project, created_by: user, title: "Boot time test case") }
  let(:req_d) { create(:requirement, section: section, project: project, created_by: user, title: "Display startup screen") }

  subject(:matrix) { described_class.new(project) }

  describe "#initialize" do
    it "accepts a project" do
      expect(matrix.project).to eq(project)
    end
  end

  describe "#requirements" do
    it "returns all requirements for the project" do
      req_a; req_b; req_c; req_d
      expect(matrix.requirements).to contain_exactly(req_a, req_b, req_c, req_d)
    end

    it "does not include requirements from other projects" do
      other_project = create(:project, organization: organization)
      other_mod = create(:requirement_module, project: other_project)
      other_section = create(:section, requirement_module: other_mod)
      create(:requirement, section: other_section, project: other_project, created_by: user)

      req_a
      expect(matrix.requirements).to contain_exactly(req_a)
    end
  end

  describe "#links" do
    it "returns all traceability links within the project" do
      link = create(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user)
      expect(matrix.links).to contain_exactly(link)
    end

    it "excludes links to requirements in other projects" do
      other_project = create(:project, organization: organization)
      other_mod = create(:requirement_module, project: other_project)
      other_section = create(:section, requirement_module: other_mod)
      external_req = create(:requirement, section: other_section, project: other_project, created_by: user)

      internal_link = create(:traceability_link, source_requirement: req_a, target_requirement: req_b, created_by: user)
      create(:traceability_link, source_requirement: req_a, target_requirement: external_req, created_by: user)

      expect(matrix.links).to contain_exactly(internal_link)
    end
  end

  describe "#generate" do
    it "returns a hash with rows, columns, cells, and summary" do
      result = matrix.generate
      expect(result).to have_key(:rows)
      expect(result).to have_key(:columns)
      expect(result).to have_key(:cells)
      expect(result).to have_key(:summary)
    end

    context "with no links" do
      it "returns empty cells" do
        req_a; req_b
        result = matrix.generate
        expect(result[:cells]).to be_empty
      end

      it "returns zero coverage in summary" do
        req_a; req_b
        result = matrix.generate
        expect(result[:summary][:total_links]).to eq(0)
        expect(result[:summary][:requirements_with_outgoing_links]).to eq(0)
        expect(result[:summary][:requirements_with_incoming_links]).to eq(0)
      end
    end

    context "with links" do
      before do
        create(:traceability_link, source_requirement: req_a, target_requirement: req_b, link_type: :derives_from, created_by: user)
        create(:traceability_link, source_requirement: req_b, target_requirement: req_c, link_type: :verifies, created_by: user)
      end

      it "populates cells with link types" do
        result = matrix.generate
        cell_key = "#{req_a.id}_#{req_b.id}"
        expect(result[:cells][cell_key]).to include("derives_from")
      end

      it "includes all linked requirements in rows and columns" do
        result = matrix.generate
        row_ids = result[:rows].map(&:id)
        col_ids = result[:columns].map(&:id)
        expect(row_ids).to include(req_a.id, req_b.id)
        expect(col_ids).to include(req_b.id, req_c.id)
      end

      it "computes correct summary" do
        result = matrix.generate
        expect(result[:summary][:total_links]).to eq(2)
        expect(result[:summary][:requirements_with_outgoing_links]).to eq(2)
        expect(result[:summary][:requirements_with_incoming_links]).to eq(2)
      end
    end

    context "with multiple link types between same requirements" do
      before do
        create(:traceability_link, source_requirement: req_a, target_requirement: req_b, link_type: :derives_from, created_by: user)
        create(:traceability_link, source_requirement: req_a, target_requirement: req_b, link_type: :refines, created_by: user)
      end

      it "shows all link types in the cell" do
        result = matrix.generate
        cell_key = "#{req_a.id}_#{req_b.id}"
        expect(result[:cells][cell_key]).to contain_exactly("derives_from", "refines")
      end
    end
  end

  describe "#generate with filters" do
    before do
      create(:traceability_link, source_requirement: req_a, target_requirement: req_b, link_type: :derives_from, created_by: user)
      create(:traceability_link, source_requirement: req_b, target_requirement: req_c, link_type: :verifies, created_by: user)
      create(:traceability_link, source_requirement: req_a, target_requirement: req_d, link_type: :satisfies, created_by: user)
    end

    it "filters by link type" do
      result = matrix.generate(link_types: [:derives_from])
      expect(result[:summary][:total_links]).to eq(1)
      cell_key = "#{req_a.id}_#{req_b.id}"
      expect(result[:cells][cell_key]).to include("derives_from")
    end

    it "filters by source requirements" do
      result = matrix.generate(source_ids: [req_b.id])
      expect(result[:summary][:total_links]).to eq(1)
      expect(result[:rows].map(&:id)).to eq([req_b.id])
    end

    it "filters by target requirements" do
      result = matrix.generate(target_ids: [req_b.id])
      expect(result[:summary][:total_links]).to eq(1)
      expect(result[:columns].map(&:id)).to eq([req_b.id])
    end
  end

  describe "#coverage_report" do
    before do
      req_a; req_b; req_c; req_d
      # a -> b (derives_from), b -> c (verifies)
      create(:traceability_link, source_requirement: req_a, target_requirement: req_b, link_type: :derives_from, created_by: user)
      create(:traceability_link, source_requirement: req_b, target_requirement: req_c, link_type: :verifies, created_by: user)
    end

    it "returns overall coverage percentages" do
      report = matrix.coverage_report
      expect(report[:total_requirements]).to eq(4)
      expect(report[:linked_requirements]).to eq(3) # a, b, c have at least one link
      expect(report[:unlinked_requirements]).to eq(1) # d has no links
      expect(report[:coverage_percentage]).to eq(75.0)
    end

    it "returns forward (outgoing) coverage" do
      report = matrix.coverage_report
      # a and b have outgoing links = 2 out of 4
      expect(report[:forward_count]).to eq(2)
      expect(report[:forward_coverage]).to eq(50.0)
    end

    it "returns backward (incoming) coverage" do
      report = matrix.coverage_report
      # b and c have incoming links = 2 out of 4
      expect(report[:backward_count]).to eq(2)
      expect(report[:backward_coverage]).to eq(50.0)
    end

    it "returns per-link-type counts" do
      report = matrix.coverage_report
      expect(report[:by_link_type]).to have_key(:derives_from)
      expect(report[:by_link_type][:derives_from][:count]).to eq(1)
      expect(report[:by_link_type]).to have_key(:verifies)
      expect(report[:by_link_type][:verifies][:count]).to eq(1)
    end

    it "returns per-link-type forward/backward coverage" do
      report = matrix.coverage_report

      derives = report[:by_link_type][:derives_from]
      expect(derives[:forward_count]).to eq(1)   # a is source
      expect(derives[:backward_count]).to eq(1)   # b is target
      expect(derives[:forward_percentage]).to eq(25.0)
      expect(derives[:backward_percentage]).to eq(25.0)

      verifies = report[:by_link_type][:verifies]
      expect(verifies[:forward_count]).to eq(1)   # b is source
      expect(verifies[:backward_count]).to eq(1)   # c is target
      expect(verifies[:forward_percentage]).to eq(25.0)
      expect(verifies[:backward_percentage]).to eq(25.0)
    end

    it "deduplicates requirements that appear in multiple links of the same type" do
      # a -> c (also derives_from) — a is already a source for derives_from
      create(:traceability_link, source_requirement: req_a, target_requirement: req_c, link_type: :derives_from, created_by: user)

      report = matrix.coverage_report
      derives = report[:by_link_type][:derives_from]
      expect(derives[:count]).to eq(2)
      expect(derives[:forward_count]).to eq(1)   # still just a
      expect(derives[:backward_count]).to eq(2)   # b and c
      expect(derives[:forward_percentage]).to eq(25.0)
      expect(derives[:backward_percentage]).to eq(50.0)
    end

    it "identifies unlinked requirements" do
      report = matrix.coverage_report
      expect(report[:unlinked_requirement_ids]).to contain_exactly(req_d.id)
    end

    it "handles project with no requirements" do
      empty_project = create(:project, organization: organization)
      empty_matrix = described_class.new(empty_project)
      report = empty_matrix.coverage_report
      expect(report[:total_requirements]).to eq(0)
      expect(report[:coverage_percentage]).to eq(0.0)
      expect(report[:forward_coverage]).to eq(0.0)
      expect(report[:backward_coverage]).to eq(0.0)
      expect(report[:forward_count]).to eq(0)
      expect(report[:backward_count]).to eq(0)
    end
  end

  describe "#test_coverage_report" do
    it "returns test coverage metrics" do
      req_a; req_b; req_c; req_d
      report = matrix.test_coverage_report
      expect(report).to have_key(:total_requirements)
      expect(report).to have_key(:tested_requirements)
      expect(report).to have_key(:untested_requirements)
      expect(report).to have_key(:test_coverage_percentage)
      expect(report).to have_key(:total_test_cases)
      expect(report).to have_key(:by_status)
      expect(report).to have_key(:requirements_with_passed)
      expect(report).to have_key(:requirements_with_failed)
      expect(report).to have_key(:requirements_with_not_run)
    end

    context "with no test cases" do
      it "returns zero coverage" do
        req_a; req_b
        report = matrix.test_coverage_report
        expect(report[:total_requirements]).to eq(2)
        expect(report[:tested_requirements]).to eq(0)
        expect(report[:untested_requirements]).to eq(2)
        expect(report[:test_coverage_percentage]).to eq(0.0)
        expect(report[:total_test_cases]).to eq(0)
      end

      it "lists all requirements as untested" do
        req_a; req_b
        report = matrix.test_coverage_report
        expect(report[:untested_requirement_ids]).to contain_exactly(req_a.id, req_b.id)
      end

      it "returns zero for all statuses" do
        req_a
        report = matrix.test_coverage_report
        expect(report[:by_status].values).to all(eq(0))
      end
    end

    context "with test cases" do
      before do
        req_a; req_b; req_c; req_d
        create(:test_case, project: project, requirement: req_a, status: :passed, created_by: user)
        create(:test_case, project: project, requirement: req_a, status: :failed, created_by: user)
        create(:test_case, project: project, requirement: req_b, status: :not_run, created_by: user)
        create(:test_case, project: project, requirement: req_c, status: :passed, created_by: user)
      end

      it "computes tested/untested counts" do
        report = matrix.test_coverage_report
        expect(report[:total_requirements]).to eq(4)
        expect(report[:tested_requirements]).to eq(3)
        expect(report[:untested_requirements]).to eq(1)
      end

      it "computes coverage percentage" do
        report = matrix.test_coverage_report
        expect(report[:test_coverage_percentage]).to eq(75.0)
      end

      it "counts total test cases" do
        report = matrix.test_coverage_report
        expect(report[:total_test_cases]).to eq(4)
      end

      it "groups test cases by status" do
        report = matrix.test_coverage_report
        expect(report[:by_status][:passed]).to eq(2)
        expect(report[:by_status][:failed]).to eq(1)
        expect(report[:by_status][:not_run]).to eq(1)
        expect(report[:by_status][:draft]).to eq(0)
      end

      it "counts requirements with passed test cases" do
        report = matrix.test_coverage_report
        expect(report[:requirements_with_passed]).to eq(2) # req_a and req_c
      end

      it "counts requirements with failed test cases" do
        report = matrix.test_coverage_report
        expect(report[:requirements_with_failed]).to eq(1) # req_a
      end

      it "counts requirements with not_run test cases" do
        report = matrix.test_coverage_report
        expect(report[:requirements_with_not_run]).to eq(1) # req_b
      end

      it "identifies untested requirements" do
        report = matrix.test_coverage_report
        expect(report[:untested_requirement_ids]).to contain_exactly(req_d.id)
      end
    end

    it "excludes test cases from other projects" do
      req_a
      other_project = create(:project, organization: organization)
      other_mod = create(:requirement_module, project: other_project)
      other_section = create(:section, requirement_module: other_mod)
      other_req = create(:requirement, section: other_section, project: other_project, created_by: user)
      create(:test_case, project: other_project, requirement: other_req, status: :passed, created_by: user)

      report = matrix.test_coverage_report
      expect(report[:total_test_cases]).to eq(0)
      expect(report[:tested_requirements]).to eq(0)
    end

    it "deduplicates requirements with multiple test cases" do
      req_a; req_b
      create(:test_case, project: project, requirement: req_a, status: :passed, created_by: user)
      create(:test_case, project: project, requirement: req_a, status: :passed, created_by: user)
      create(:test_case, project: project, requirement: req_a, status: :failed, created_by: user)

      report = matrix.test_coverage_report
      expect(report[:tested_requirements]).to eq(1)
      expect(report[:requirements_with_passed]).to eq(1)
      expect(report[:test_coverage_percentage]).to eq(50.0)
    end

    it "handles empty project" do
      empty_project = create(:project, organization: organization)
      empty_matrix = described_class.new(empty_project)
      report = empty_matrix.test_coverage_report
      expect(report[:total_requirements]).to eq(0)
      expect(report[:test_coverage_percentage]).to eq(0.0)
      expect(report[:total_test_cases]).to eq(0)
      expect(report[:by_status].values).to all(eq(0))
    end
  end
end
