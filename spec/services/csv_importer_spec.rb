require "rails_helper"

RSpec.describe CsvImporter do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization, prefix: "CSV") }

  subject(:importer) { described_class.new(project, user) }

  describe "#initialize" do
    it "sets project and user" do
      expect(importer.project).to eq(project)
      expect(importer.user).to eq(user)
    end

    it "initializes counters to zero" do
      expect(importer.imported_count).to eq(0)
      expect(importer.skipped_count).to eq(0)
      expect(importer.errors).to be_empty
    end
  end

  describe "#import" do
    context "with valid CSV" do
      let(:csv_content) do
        <<~CSV
          title,body,requirement_type,status,priority,asil_level,module,section
          Brake System Req,The system shall apply brakes within 100ms,functional,draft,must_have,asil_d,Braking,Safety
          Steering Req,The system shall provide power steering assist,safety,in_review,should_have,asil_b,Steering,Performance
        CSV
      end

      it "imports requirements successfully" do
        result = importer.import(csv_content)

        expect(result[:success]).to be true
        expect(result[:imported]).to eq(2)
        expect(result[:skipped]).to eq(0)
        expect(result[:errors]).to be_empty
      end

      it "creates requirement records with correct attributes" do
        importer.import(csv_content)

        req1 = project.requirements.find_by(title: "Brake System Req")
        expect(req1).to be_present
        expect(req1.body).to eq("The system shall apply brakes within 100ms")
        expect(req1.requirement_type).to eq("functional")
        expect(req1.status).to eq("draft")
        expect(req1.priority).to eq("must_have")
        expect(req1.asil_level).to eq("asil_d")
        expect(req1.created_by).to eq(user)
      end

      it "auto-generates UIDs" do
        importer.import(csv_content)

        uids = project.requirements.pluck(:uid)
        expect(uids).to contain_exactly("CSV-0001", "CSV-0002")
      end

      it "creates modules and sections" do
        importer.import(csv_content)

        expect(project.requirement_modules.pluck(:name)).to contain_exactly("Braking", "Steering")
        expect(Section.where(requirement_module: project.requirement_modules).pluck(:name)).to contain_exactly("Safety", "Performance")
      end

      it "assigns requirements to correct sections" do
        importer.import(csv_content)

        req1 = project.requirements.find_by(title: "Brake System Req")
        expect(req1.section.name).to eq("Safety")
        expect(req1.section.requirement_module.name).to eq("Braking")
      end

      it "reuses existing modules and sections" do
        mod = create(:requirement_module, project: project, name: "Braking")
        section = create(:section, requirement_module: mod, name: "Safety")

        importer.import(csv_content)

        expect(project.requirement_modules.where(name: "Braking").count).to eq(1)
        expect(Section.where(requirement_module: mod, name: "Safety").count).to eq(1)
        expect(project.requirements.find_by(title: "Brake System Req").section).to eq(section)
      end
    end

    context "with minimal CSV (title only)" do
      let(:csv_content) do
        <<~CSV
          title
          Simple requirement
          Another requirement
        CSV
      end

      it "imports with defaults" do
        result = importer.import(csv_content)

        expect(result[:success]).to be true
        expect(result[:imported]).to eq(2)

        req = project.requirements.find_by(title: "Simple requirement")
        expect(req.requirement_type).to eq("functional")
        expect(req.status).to eq("draft")
        expect(req.priority).to eq("must_have")
        expect(req.asil_level).to eq("qm")
      end

      it "creates default module and section" do
        importer.import(csv_content)

        expect(project.requirement_modules.pluck(:name)).to include("Imported")
        mod = project.requirement_modules.find_by(name: "Imported")
        expect(mod.sections.pluck(:name)).to include("Default")
      end
    end

    context "with explicit UIDs" do
      let(:csv_content) do
        <<~CSV
          uid,title,body
          CUSTOM-001,Req with UID,Has explicit UID
          ,Req without UID,Gets auto-generated UID
        CSV
      end

      it "preserves explicit UIDs" do
        importer.import(csv_content)

        expect(project.requirements.find_by(title: "Req with UID").uid).to eq("CUSTOM-001")
      end

      it "auto-generates UIDs for rows without one" do
        importer.import(csv_content)

        req = project.requirements.find_by(title: "Req without UID")
        expect(req.uid).to match(/^CSV-\d{4}$/)
      end
    end

    context "with custom attributes (unmapped columns)" do
      let(:csv_content) do
        <<~CSV
          title,body,Verification Method,Safety Classification
          Custom Req,Some body,Test,ASIL-B
        CSV
      end

      it "stores unmapped columns in custom_attributes" do
        importer.import(csv_content)

        req = project.requirements.find_by(title: "Custom Req")
        expect(req.custom_attributes).to eq({
          "Verification Method" => "Test",
          "Safety Classification" => "ASIL-B"
        })
      end
    end

    context "with alternative column names" do
      let(:csv_content) do
        <<~CSV
          title,description,type,asil,module_name,section_name
          Alt Names Req,Body via description,safety,asil_c,AltModule,AltSection
        CSV
      end

      it "maps alternative column names correctly" do
        importer.import(csv_content)

        req = project.requirements.find_by(title: "Alt Names Req")
        expect(req.body).to eq("Body via description")
        expect(req.requirement_type).to eq("safety")
        expect(req.asil_level).to eq("asil_c")
        expect(req.section.name).to eq("AltSection")
        expect(req.section.requirement_module.name).to eq("AltModule")
      end
    end

    context "with case-insensitive headers" do
      let(:csv_content) do
        <<~CSV
          Title,Body,REQUIREMENT_TYPE,STATUS
          Case Test,Body text,FUNCTIONAL,DRAFT
        CSV
      end

      it "handles case-insensitive headers" do
        result = importer.import(csv_content)

        expect(result[:success]).to be true
        req = project.requirements.find_by(title: "Case Test")
        expect(req.requirement_type).to eq("functional")
        expect(req.status).to eq("draft")
      end
    end

    context "with invalid enum values" do
      let(:csv_content) do
        <<~CSV
          title,requirement_type,status,priority,asil_level
          Invalid Enums,bogus_type,fake_status,bad_priority,invalid_asil
        CSV
      end

      it "falls back to defaults for invalid enums" do
        result = importer.import(csv_content)

        expect(result[:success]).to be true
        req = project.requirements.find_by(title: "Invalid Enums")
        expect(req.requirement_type).to eq("functional")
        expect(req.status).to eq("draft")
        expect(req.priority).to eq("must_have")
        expect(req.asil_level).to eq("qm")
      end
    end

    context "with enum values containing spaces/hyphens" do
      let(:csv_content) do
        <<~CSV
          title,requirement_type,status,priority,asil_level
          Normalized Enums,non functional,in review,should have,asil-b
        CSV
      end

      it "normalizes enum values with spaces and hyphens" do
        result = importer.import(csv_content)

        expect(result[:success]).to be true
        req = project.requirements.find_by(title: "Normalized Enums")
        expect(req.requirement_type).to eq("non_functional")
        expect(req.status).to eq("in_review")
        expect(req.priority).to eq("should_have")
        expect(req.asil_level).to eq("asil_b")
      end
    end

    context "with blank title rows" do
      let(:csv_content) do
        <<~CSV
          title,body
          Valid Req,Has a title
          ,Missing title
          Another Valid,Also has a title
        CSV
      end

      it "skips rows with blank titles and records errors" do
        result = importer.import(csv_content)

        expect(result[:success]).to be false
        expect(result[:imported]).to eq(0)
        expect(result[:skipped]).to eq(1)
        expect(result[:errors].length).to eq(1)
        expect(result[:errors].first[:row]).to eq(3)
        expect(result[:errors].first[:message]).to include("Title is required")
      end

      it "rolls back all changes on any error" do
        importer.import(csv_content)

        expect(project.requirements.count).to eq(0)
      end
    end

    context "with duplicate UIDs" do
      let(:csv_content) do
        <<~CSV
          uid,title
          DUP-001,First requirement
          DUP-001,Second with same UID
        CSV
      end

      it "records validation error for duplicate UID" do
        result = importer.import(csv_content)

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
        dup_error = result[:errors].find { |e| e[:message].include?("Uid") }
        expect(dup_error).to be_present
      end
    end

    context "with empty CSV" do
      it "raises ValidationError for empty content" do
        expect { importer.import("title\n") }.to raise_error(
          CsvImporter::ValidationError, /empty/
        )
      end
    end

    context "with missing required columns" do
      let(:csv_content) do
        <<~CSV
          body,status
          No title column,draft
        CSV
      end

      it "raises ValidationError for missing title column" do
        expect { importer.import(csv_content) }.to raise_error(
          CsvImporter::ValidationError, /Missing required columns: title/
        )
      end
    end

    context "with malformed CSV" do
      it "raises ValidationError for invalid CSV" do
        expect { importer.import("\"unclosed quote") }.to raise_error(
          CsvImporter::ValidationError, /Invalid CSV format/
        )
      end
    end

    context "with multiple requirements in same module/section" do
      let(:csv_content) do
        <<~CSV
          title,module,section
          Req A,SharedModule,SharedSection
          Req B,SharedModule,SharedSection
          Req C,SharedModule,DifferentSection
        CSV
      end

      it "reuses modules and sections for multiple requirements" do
        result = importer.import(csv_content)

        expect(result[:imported]).to eq(3)
        expect(project.requirement_modules.count).to eq(1)

        mod = project.requirement_modules.first
        expect(mod.sections.count).to eq(2)
        expect(mod.sections.find_by(name: "SharedSection").requirements.count).to eq(2)
      end
    end

    context "with whitespace in values" do
      let(:csv_content) do
        <<~CSV
          title,body,module,section
          "  Padded Title  ","  Padded Body  ","  Padded Module  ","  Padded Section  "
        CSV
      end

      it "strips whitespace from values" do
        result = importer.import(csv_content)

        expect(result[:success]).to be true
        req = project.requirements.first
        expect(req.title).to eq("Padded Title")
        expect(req.body).to eq("Padded Body")
        expect(req.section.name).to eq("Padded Section")
        expect(req.section.requirement_module.name).to eq("Padded Module")
      end
    end

    context "with large import" do
      let(:csv_content) do
        header = "title,body,module,section,requirement_type,status\n"
        rows = (1..25).map { |i| "Req #{i},Body #{i},Module #{(i % 3) + 1},Section #{(i % 2) + 1},functional,draft" }
        header + rows.join("\n")
      end

      it "imports all rows in a single transaction" do
        result = importer.import(csv_content)

        expect(result[:success]).to be true
        expect(result[:imported]).to eq(25)
        expect(project.requirements.count).to eq(25)
      end
    end

    context "counter state after import" do
      let(:csv_content) do
        <<~CSV
          title
          Counter Test
        CSV
      end

      it "updates instance counters" do
        importer.import(csv_content)

        expect(importer.imported_count).to eq(1)
        expect(importer.skipped_count).to eq(0)
        expect(importer.errors).to be_empty
      end
    end

    context "with BOM-encoded content" do
      let(:csv_content) do
        "\xEF\xBB\xBFtitle,body\nBOM Req,Has BOM"
      end

      it "handles UTF-8 BOM gracefully" do
        result = importer.import(csv_content)

        expect(result[:success]).to be true
        expect(result[:imported]).to eq(1)
      end
    end
  end

  describe "#import_file" do
    it "reads file and delegates to import" do
      file = Tempfile.new(["test", ".csv"])
      file.write("title,body\nFile Req,From file\n")
      file.rewind
      file.close

      result = importer.import_file(file.path)

      expect(result[:success]).to be true
      expect(result[:imported]).to eq(1)
      expect(project.requirements.find_by(title: "File Req")).to be_present
    ensure
      file.unlink
    end
  end

  describe "constants" do
    it "defines required columns" do
      expect(CsvImporter::REQUIRED_COLUMNS).to include("title")
    end

    it "maps all standard column names" do
      expect(CsvImporter::COLUMN_MAPPINGS).to include(
        "uid" => :uid,
        "title" => :title,
        "body" => :body,
        "description" => :body,
        "requirement_type" => :requirement_type,
        "type" => :requirement_type,
        "status" => :status,
        "priority" => :priority,
        "asil_level" => :asil_level,
        "asil" => :asil_level,
        "module" => :module_name,
        "section" => :section_name
      )
    end

    it "uses valid enums from Requirement model" do
      expect(CsvImporter::VALID_REQUIREMENT_TYPES).to eq(Requirement.requirement_types.keys)
      expect(CsvImporter::VALID_STATUSES).to eq(Requirement.statuses.keys)
      expect(CsvImporter::VALID_PRIORITIES).to eq(Requirement.priorities.keys)
      expect(CsvImporter::VALID_ASIL_LEVELS).to eq(Requirement.asil_levels.keys)
    end
  end
end
