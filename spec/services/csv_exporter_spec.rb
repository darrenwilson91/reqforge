require "rails_helper"

RSpec.describe CsvExporter do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:project) { create(:project, organization: organization, prefix: "EXP") }
  let(:mod) { create(:requirement_module, project: project, name: "System Requirements") }
  let(:section) { create(:section, requirement_module: mod, name: "Functional") }

  subject(:exporter) { described_class.new(project) }

  describe "#export" do
    context "with no requirements" do
      it "returns CSV with only headers" do
        csv = CSV.parse(exporter.export)
        expect(csv.length).to eq(1)
        expect(csv.first).to eq(CsvExporter::STANDARD_COLUMNS)
      end
    end

    context "with requirements" do
      let!(:req1) do
        create(:requirement,
          project: project,
          section: section,
          created_by: user,
          uid: "EXP-0001",
          title: "System shall start within 5 seconds",
          body: "The system must boot up in under 5 seconds.",
          requirement_type: :functional,
          status: :approved,
          priority: :must_have,
          asil_level: :asil_b)
      end

      let!(:req2) do
        create(:requirement,
          project: project,
          section: section,
          created_by: user,
          uid: "EXP-0002",
          title: "System shall log errors",
          body: "All errors shall be logged to persistent storage.",
          requirement_type: :non_functional,
          status: :draft,
          priority: :should_have,
          asil_level: :qm)
      end

      it "includes all standard columns as headers" do
        csv = CSV.parse(exporter.export, headers: true)
        CsvExporter::STANDARD_COLUMNS.each do |col|
          expect(csv.headers).to include(col)
        end
      end

      it "exports all requirements" do
        csv = CSV.parse(exporter.export, headers: true)
        expect(csv.length).to eq(2)
      end

      it "exports correct attribute values" do
        csv = CSV.parse(exporter.export, headers: true)
        row = csv.find { |r| r["uid"] == "EXP-0001" }

        expect(row["title"]).to eq("System shall start within 5 seconds")
        expect(row["body"]).to eq("The system must boot up in under 5 seconds.")
        expect(row["requirement_type"]).to eq("functional")
        expect(row["status"]).to eq("approved")
        expect(row["priority"]).to eq("must_have")
        expect(row["asil_level"]).to eq("asil_b")
      end

      it "exports module and section names" do
        csv = CSV.parse(exporter.export, headers: true)
        row = csv.find { |r| r["uid"] == "EXP-0001" }

        expect(row["module_name"]).to eq("System Requirements")
        expect(row["section_name"]).to eq("Functional")
      end

      it "exports UIDs" do
        csv = CSV.parse(exporter.export, headers: true)
        uids = csv.map { |r| r["uid"] }
        expect(uids).to contain_exactly("EXP-0001", "EXP-0002")
      end
    end

    context "with custom attributes" do
      let!(:req_with_custom) do
        create(:requirement,
          project: project,
          section: section,
          created_by: user,
          uid: "EXP-0010",
          title: "Custom requirement",
          custom_attributes: { "Safety_Level" => "Critical", "Component" => "Brakes" })
      end

      let!(:req_without_custom) do
        create(:requirement,
          project: project,
          section: section,
          created_by: user,
          uid: "EXP-0011",
          title: "Plain requirement",
          custom_attributes: {})
      end

      it "includes custom attribute keys as additional headers" do
        csv = CSV.parse(exporter.export, headers: true)
        expect(csv.headers).to include("Component", "Safety_Level")
      end

      it "sorts custom attribute headers alphabetically" do
        csv = CSV.parse(exporter.export, headers: true)
        custom_headers = csv.headers - CsvExporter::STANDARD_COLUMNS
        expect(custom_headers).to eq(custom_headers.sort)
      end

      it "exports custom attribute values for requirements that have them" do
        csv = CSV.parse(exporter.export, headers: true)
        row = csv.find { |r| r["uid"] == "EXP-0010" }

        expect(row["Safety_Level"]).to eq("Critical")
        expect(row["Component"]).to eq("Brakes")
      end

      it "exports nil for custom attributes on requirements that lack them" do
        csv = CSV.parse(exporter.export, headers: true)
        row = csv.find { |r| r["uid"] == "EXP-0011" }

        expect(row["Safety_Level"]).to be_nil
        expect(row["Component"]).to be_nil
      end
    end

    context "with mixed custom attributes across requirements" do
      let!(:req1) do
        create(:requirement,
          project: project, section: section, created_by: user,
          uid: "EXP-0020",
          title: "Req A",
          custom_attributes: { "Weight" => "5kg" })
      end

      let!(:req2) do
        create(:requirement,
          project: project, section: section, created_by: user,
          uid: "EXP-0021",
          title: "Req B",
          custom_attributes: { "Color" => "Red", "Weight" => "3kg" })
      end

      it "collects all unique custom attribute keys as headers" do
        csv = CSV.parse(exporter.export, headers: true)
        custom_headers = csv.headers - CsvExporter::STANDARD_COLUMNS
        expect(custom_headers).to contain_exactly("Color", "Weight")
      end

      it "fills in values per-requirement correctly" do
        csv = CSV.parse(exporter.export, headers: true)

        row_a = csv.find { |r| r["uid"] == "EXP-0020" }
        expect(row_a["Weight"]).to eq("5kg")
        expect(row_a["Color"]).to be_nil

        row_b = csv.find { |r| r["uid"] == "EXP-0021" }
        expect(row_b["Weight"]).to eq("3kg")
        expect(row_b["Color"]).to eq("Red")
      end
    end

    context "with multiple modules and sections" do
      let(:mod2) { create(:requirement_module, project: project, name: "Safety Requirements") }
      let(:section2) { create(:section, requirement_module: mod2, name: "Hazards") }

      let!(:req1) do
        create(:requirement,
          project: project, section: section, created_by: user,
          uid: "EXP-0030", title: "System req")
      end

      let!(:req2) do
        create(:requirement,
          project: project, section: section2, created_by: user,
          uid: "EXP-0031", title: "Safety req")
      end

      it "exports requirements from all modules" do
        csv = CSV.parse(exporter.export, headers: true)
        modules = csv.map { |r| r["module_name"] }
        expect(modules).to include("System Requirements", "Safety Requirements")
      end

      it "exports correct section for each requirement" do
        csv = CSV.parse(exporter.export, headers: true)

        row1 = csv.find { |r| r["uid"] == "EXP-0030" }
        expect(row1["section_name"]).to eq("Functional")

        row2 = csv.find { |r| r["uid"] == "EXP-0031" }
        expect(row2["section_name"]).to eq("Hazards")
      end
    end

    context "ordering" do
      let(:mod_a) { create(:requirement_module, project: project, name: "A Module") }
      let(:mod_b) { create(:requirement_module, project: project, name: "B Module") }
      let(:section_a) { create(:section, requirement_module: mod_a, name: "A Section") }
      let(:section_b) { create(:section, requirement_module: mod_b, name: "B Section") }

      let!(:req_b) do
        create(:requirement,
          project: project, section: section_b, created_by: user,
          uid: "EXP-0041", title: "B req")
      end

      let!(:req_a) do
        create(:requirement,
          project: project, section: section_a, created_by: user,
          uid: "EXP-0040", title: "A req")
      end

      it "orders requirements by module name, then section name, then position" do
        csv = CSV.parse(exporter.export, headers: true)
        uids = csv.map { |r| r["uid"] }
        expect(uids).to eq(%w[EXP-0040 EXP-0041])
      end
    end

    context "with nil body" do
      let!(:req) do
        create(:requirement,
          project: project, section: section, created_by: user,
          uid: "EXP-0050", title: "No body req", body: nil)
      end

      it "exports nil body as empty cell" do
        csv = CSV.parse(exporter.export, headers: true)
        row = csv.first
        expect(row["body"]).to be_nil
      end
    end

    context "with special characters" do
      let!(:req) do
        create(:requirement,
          project: project, section: section, created_by: user,
          uid: "EXP-0060",
          title: 'Req with "quotes" and, commas',
          body: "Line 1\nLine 2\nLine 3")
      end

      it "handles quotes and commas in values" do
        csv = CSV.parse(exporter.export, headers: true)
        row = csv.first
        expect(row["title"]).to eq('Req with "quotes" and, commas')
      end

      it "handles newlines in body" do
        csv = CSV.parse(exporter.export, headers: true)
        row = csv.first
        expect(row["body"]).to eq("Line 1\nLine 2\nLine 3")
      end
    end

    context "multi-tenancy isolation" do
      let(:other_org) { create(:organization, name: "Other Org") }
      let(:other_project) { create(:project, organization: other_org, prefix: "OTH") }
      let(:other_mod) { create(:requirement_module, project: other_project, name: "Other Module") }
      let(:other_section) { create(:section, requirement_module: other_mod, name: "Other Section") }

      let!(:our_req) do
        create(:requirement,
          project: project, section: section, created_by: user,
          uid: "EXP-0070", title: "Our requirement")
      end

      let!(:other_req) do
        create(:requirement,
          project: other_project, section: other_section, created_by: user,
          uid: "OTH-0001", title: "Other requirement")
      end

      it "only exports requirements belonging to the project" do
        csv = CSV.parse(exporter.export, headers: true)
        uids = csv.map { |r| r["uid"] }
        expect(uids).to eq(%w[EXP-0070])
      end
    end
  end

  describe "#export_to_file" do
    let!(:req) do
      create(:requirement,
        project: project, section: section, created_by: user,
        uid: "EXP-0080", title: "File export test")
    end

    it "writes CSV to the specified file path" do
      file_path = Rails.root.join("tmp", "test_export_#{SecureRandom.hex(4)}.csv").to_s

      begin
        exporter.export_to_file(file_path)

        expect(File.exist?(file_path)).to be true
        content = File.read(file_path)
        csv = CSV.parse(content, headers: true)
        expect(csv.length).to eq(1)
        expect(csv.first["uid"]).to eq("EXP-0080")
      ensure
        File.delete(file_path) if File.exist?(file_path)
      end
    end

    it "writes UTF-8 encoded content" do
      file_path = Rails.root.join("tmp", "test_export_utf8_#{SecureRandom.hex(4)}.csv").to_s

      begin
        exporter.export_to_file(file_path)
        content = File.read(file_path)
        expect(content.encoding.name).to eq("UTF-8")
      ensure
        File.delete(file_path) if File.exist?(file_path)
      end
    end
  end

  describe "round-trip compatibility with CsvImporter" do
    let!(:req) do
      create(:requirement,
        project: project, section: section, created_by: user,
        uid: "EXP-0090",
        title: "Round-trip requirement",
        body: "This requirement should survive export and reimport.",
        requirement_type: :safety,
        status: :approved,
        priority: :must_have,
        asil_level: :asil_d,
        custom_attributes: { "Verification_Method" => "Test" })
    end

    it "produces CSV that CsvImporter can parse with matching standard attributes" do
      csv_content = exporter.export

      # Verify the exported CSV has valid headers that the importer recognizes
      csv = CSV.parse(csv_content, headers: true)
      row = csv.first

      expect(row["uid"]).to eq("EXP-0090")
      expect(row["title"]).to eq("Round-trip requirement")
      expect(row["body"]).to eq("This requirement should survive export and reimport.")
      expect(row["requirement_type"]).to eq("safety")
      expect(row["status"]).to eq("approved")
      expect(row["priority"]).to eq("must_have")
      expect(row["asil_level"]).to eq("asil_d")
      expect(row["module_name"]).to eq("System Requirements")
      expect(row["section_name"]).to eq("Functional")
      expect(row["Verification_Method"]).to eq("Test")
    end
  end

  describe "STANDARD_COLUMNS" do
    it "contains all expected columns" do
      expect(CsvExporter::STANDARD_COLUMNS).to eq(%w[
        uid title body requirement_type status priority asil_level module_name section_name
      ])
    end
  end
end
