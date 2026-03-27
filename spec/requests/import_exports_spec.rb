require "rails_helper"

RSpec.describe "ImportExports", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization, prefix: "TEST") }

  before { sign_in user }

  describe "GET /projects/:project_id/import_export" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        get project_import_export_path(project)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it "renders the import/export page" do
      get project_import_export_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Import / Export")
    end

    it "shows breadcrumbs" do
      get project_import_export_path(project)
      expect(response.body).to include("Projects")
      expect(response.body).to include(project.name)
      expect(response.body).to include("Import / Export")
    end

    it "shows export buttons" do
      get project_import_export_path(project)
      expect(response.body).to include("Download CSV")
      expect(response.body).to include("Download ReqIF")
    end

    it "shows import forms for admin" do
      get project_import_export_path(project)
      expect(response.body).to include("Import CSV")
      expect(response.body).to include("Import ReqIF")
    end

    it "shows the requirement count" do
      section = create(:section, requirement_module: create(:requirement_module, project: project))
      create_list(:requirement, 3, project: project, section: section, created_by: user)
      get project_import_export_path(project)
      expect(response.body).to include("3 requirements")
    end

    it "shows CSV format reference" do
      get project_import_export_path(project)
      expect(response.body).to include("CSV Format Reference")
      expect(response.body).to include("Supported Columns")
    end

    context "as a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "renders the page but hides import forms" do
        get project_import_export_path(project)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Download CSV")
        expect(response.body).to include("Import not available")
        expect(response.body).not_to include("Import CSV")
      end
    end

    context "cross-organization" do
      let(:other_org) { create(:organization) }
      let(:other_project) { create(:project, organization: other_org) }

      it "returns 404" do
        get project_import_export_path(other_project)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /projects/:project_id/import_export/export_csv" do
    it "downloads a CSV file" do
      get export_csv_project_import_export_path(project)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("TEST_requirements_")
      expect(response.headers["Content-Disposition"]).to include(".csv")
    end

    it "includes requirements in the CSV" do
      section = create(:section, requirement_module: create(:requirement_module, project: project))
      req = create(:requirement, project: project, section: section, created_by: user, title: "My Req Title")
      get export_csv_project_import_export_path(project)
      expect(response.body).to include("My Req Title")
      expect(response.body).to include(req.uid)
    end

    it "works for empty projects" do
      get export_csv_project_import_export_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("uid,title,body")
    end

    context "as a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "allows export" do
        get export_csv_project_import_export_path(project)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /projects/:project_id/import_export/export_reqif" do
    it "downloads a ReqIF file" do
      get export_reqif_project_import_export_path(project)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/xml")
      expect(response.headers["Content-Disposition"]).to include("TEST_requirements_")
      expect(response.headers["Content-Disposition"]).to include(".reqif")
    end

    it "includes valid ReqIF XML" do
      get export_reqif_project_import_export_path(project)
      expect(response.body).to include("REQ-IF")
      expect(response.body).to include("ReqForge")
    end

    context "as a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "allows export" do
        get export_reqif_project_import_export_path(project)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "POST /projects/:project_id/import_export/import_csv" do
    let(:csv_content) { "title,body\nReq One,Description One\nReq Two,Description Two\n" }
    let(:csv_file) { fixture_file_upload(StringIO.new(csv_content), "text/csv", false, filename: "import.csv") }

    # Helper to create an uploaded file from string content
    def csv_upload(content, filename: "import.csv", content_type: "text/csv")
      file = Tempfile.new([ "csv_import", ".csv" ])
      file.write(content)
      file.rewind
      Rack::Test::UploadedFile.new(file.path, content_type, false, original_filename: filename)
    end

    it "imports requirements from CSV" do
      expect {
        post import_csv_project_import_export_path(project), params: { file: csv_upload(csv_content) }
      }.to change(Requirement, :count).by(2)
      expect(response).to redirect_to(project_import_export_path(project))
      follow_redirect!
      expect(response.body).to include("Successfully imported 2 requirements from CSV")
    end

    it "redirects with error when no file selected" do
      post import_csv_project_import_export_path(project)
      expect(response).to redirect_to(project_import_export_path(project))
      expect(flash[:alert]).to include("Please select a CSV file")
    end

    it "redirects with error for invalid file type" do
      file = Tempfile.new([ "test", ".json" ])
      file.write('{"invalid": true}')
      file.rewind
      upload = Rack::Test::UploadedFile.new(file.path, "application/json")

      post import_csv_project_import_export_path(project), params: { file: upload }
      expect(response).to redirect_to(project_import_export_path(project))
      expect(flash[:alert]).to include("Invalid file type")
    end

    it "handles CSV with validation errors" do
      bad_csv = "title\n\n"
      post import_csv_project_import_export_path(project), params: { file: csv_upload(bad_csv) }
      expect(response).to redirect_to(project_import_export_path(project))
      expect(flash[:alert]).to be_present
    end

    it "handles malformed CSV" do
      malformed = "title\n\"unclosed quote"
      post import_csv_project_import_export_path(project), params: { file: csv_upload(malformed) }
      expect(response).to redirect_to(project_import_export_path(project))
      expect(flash[:alert]).to include("CSV import error")
    end

    context "as a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "denies import" do
        expect {
          post import_csv_project_import_export_path(project), params: { file: csv_upload(csv_content) }
        }.not_to change(Requirement, :count)
      end
    end

    context "as a project manager" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :project_manager) }

      it "allows import" do
        expect {
          post import_csv_project_import_export_path(project), params: { file: csv_upload(csv_content) }
        }.to change(Requirement, :count).by(2)
      end
    end
  end

  describe "POST /projects/:project_id/import_export/import_reqif" do
    def reqif_upload(content, filename: "import.reqif")
      file = Tempfile.new([ "reqif_import", ".reqif" ])
      file.write(content)
      file.rewind
      Rack::Test::UploadedFile.new(file.path, "application/xml", false, original_filename: filename)
    end

    let(:reqif_xml) do
      # Generate valid ReqIF from an export of the project with some requirements
      section = create(:section, requirement_module: create(:requirement_module, project: project))
      create(:requirement, project: project, section: section, created_by: user, title: "Exported Req")
      exporter = ReqifExporter.new(project)
      exporter.export
    end

    it "redirects with error when no file selected" do
      post import_reqif_project_import_export_path(project)
      expect(response).to redirect_to(project_import_export_path(project))
      expect(flash[:alert]).to include("Please select a ReqIF file")
    end

    it "redirects with error for invalid file extension" do
      file = Tempfile.new([ "test", ".json" ])
      file.write('{"invalid": true}')
      file.rewind
      upload = Rack::Test::UploadedFile.new(file.path, "application/json", false, original_filename: "test.json")

      post import_reqif_project_import_export_path(project), params: { file: upload }
      expect(response).to redirect_to(project_import_export_path(project))
      expect(flash[:alert]).to include("Invalid file type")
    end

    it "handles invalid XML" do
      post import_reqif_project_import_export_path(project), params: { file: reqif_upload("<not>valid</xml>") }
      expect(response).to redirect_to(project_import_export_path(project))
      expect(flash[:alert]).to be_present
    end

    it "imports requirements from ReqIF and redirects with result" do
      # Build a minimal valid ReqIF XML
      minimal_reqif = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <REQ-IF xmlns="http://www.omg.org/spec/ReqIF/20110401/reqif.xsd">
          <THE-HEADER><REQ-IF-HEADER IDENTIFIER="test"><CREATION-TIME>2026-01-01T00:00:00Z</CREATION-TIME><REQ-IF-TOOL-ID>Test</REQ-IF-TOOL-ID><REQ-IF-VERSION>1.2</REQ-IF-VERSION><SOURCE-TOOL-ID>Test</SOURCE-TOOL-ID><TITLE>Test</TITLE></REQ-IF-HEADER></THE-HEADER>
          <CORE-CONTENT>
            <REQ-IF-CONTENT>
              <DATATYPES>
                <DATATYPE-DEFINITION-STRING IDENTIFIER="dt-string" LONG-NAME="String" MAX-LENGTH="4000"/>
              </DATATYPES>
              <SPEC-TYPES>
                <SPEC-OBJECT-TYPE IDENTIFIER="sot-1" LONG-NAME="Requirement">
                  <SPEC-ATTRIBUTES>
                    <ATTRIBUTE-DEFINITION-STRING IDENTIFIER="ad-title" LONG-NAME="title">
                      <TYPE><DATATYPE-DEFINITION-STRING-REF>dt-string</DATATYPE-DEFINITION-STRING-REF></TYPE>
                    </ATTRIBUTE-DEFINITION-STRING>
                  </SPEC-ATTRIBUTES>
                </SPEC-OBJECT-TYPE>
              </SPEC-TYPES>
              <SPEC-OBJECTS>
                <SPEC-OBJECT IDENTIFIER="so-1" LAST-CHANGE="2026-01-01T00:00:00Z">
                  <VALUES>
                    <ATTRIBUTE-VALUE-STRING THE-VALUE="ReqIF Imported Req">
                      <DEFINITION><ATTRIBUTE-DEFINITION-STRING-REF>ad-title</ATTRIBUTE-DEFINITION-STRING-REF></DEFINITION>
                    </ATTRIBUTE-VALUE-STRING>
                  </VALUES>
                  <TYPE><SPEC-OBJECT-TYPE-REF>sot-1</SPEC-OBJECT-TYPE-REF></TYPE>
                </SPEC-OBJECT>
              </SPEC-OBJECTS>
              <SPEC-RELATIONS/>
              <SPECIFICATIONS/>
            </REQ-IF-CONTENT>
          </CORE-CONTENT>
        </REQ-IF>
      XML

      expect {
        post import_reqif_project_import_export_path(project), params: { file: reqif_upload(minimal_reqif) }
      }.to change(Requirement, :count).by(1)
      expect(response).to redirect_to(project_import_export_path(project))
      follow_redirect!
      expect(response.body).to include("Successfully imported")
    end

    context "as a viewer" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :viewer) }

      it "denies import" do
        post import_reqif_project_import_export_path(project), params: { file: reqif_upload("<REQ-IF/>") }
        # Viewer gets redirected or forbidden
        expect(response).not_to have_http_status(:success)
      end
    end

    context "as a project manager" do
      let!(:membership) { create(:membership, user: user, organization: organization, role: :project_manager) }

      it "allows import" do
        post import_reqif_project_import_export_path(project), params: { file: reqif_upload("<REQ-IF/>") }
        expect(response).to redirect_to(project_import_export_path(project))
      end
    end
  end
end
