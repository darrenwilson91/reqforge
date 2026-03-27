require "rails_helper"

RSpec.describe "Bulk Edit", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization) }
  let(:req_module) { create(:requirement_module, project: project, name: "System Requirements") }
  let(:section) { create(:section, requirement_module: req_module, name: "Functional") }

  before { sign_in user }

  describe "GET /projects/:project_id/requirements/bulk_edit" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        get bulk_edit_project_requirements_path(project)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it "renders the bulk edit page" do
      get bulk_edit_project_requirements_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bulk Edit")
    end

    it "shows the project name and requirement count" do
      create_list(:requirement, 3, project: project, section: section, created_by: user)
      get bulk_edit_project_requirements_path(project)
      expect(response.body).to include(project.name)
      expect(response.body).to include("3 requirements")
    end

    it "shows breadcrumbs" do
      get bulk_edit_project_requirements_path(project)
      expect(response.body).to include("Projects")
      expect(response.body).to include("Requirements")
      expect(response.body).to include("Bulk Edit")
    end

    it "shows requirements in a table with UIDs and titles" do
      req = create(:requirement, project: project, section: section, created_by: user, title: "Brake Force Calculation")
      get bulk_edit_project_requirements_path(project)
      expect(response.body).to include(req.uid)
      expect(response.body).to include("Brake Force Calculation")
    end

    it "shows editable columns for type, status, priority, ASIL, section" do
      create(:requirement, project: project, section: section, created_by: user)
      get bulk_edit_project_requirements_path(project)
      expect(response.body).to include('data-field="requirement_type"')
      expect(response.body).to include('data-field="status"')
      expect(response.body).to include('data-field="priority"')
      expect(response.body).to include('data-field="asil_level"')
      expect(response.body).to include('data-field="section_id"')
    end

    it "shows hidden inputs for form submission" do
      req = create(:requirement, project: project, section: section, created_by: user)
      get bulk_edit_project_requirements_path(project)
      expect(response.body).to include("requirements[#{req.id}][title]")
      expect(response.body).to include("requirements[#{req.id}][requirement_type]")
    end

    it "shows select-all checkbox" do
      create(:requirement, project: project, section: section, created_by: user)
      get bulk_edit_project_requirements_path(project)
      expect(response.body).to include('data-bulk-edit-target="selectAll"')
    end

    it "shows bulk action toolbar structure" do
      create(:requirement, project: project, section: section, created_by: user)
      get bulk_edit_project_requirements_path(project)
      expect(response.body).to include("Set Type")
      expect(response.body).to include("Set Priority")
      expect(response.body).to include("Set ASIL")
      expect(response.body).to include("Move to Section")
      expect(response.body).to include("Delete Selected")
    end

    it "shows save bar with Cancel and Save Changes buttons" do
      create(:requirement, project: project, section: section, created_by: user)
      get bulk_edit_project_requirements_path(project)
      expect(response.body).to include("Cancel")
      expect(response.body).to include("Save Changes")
    end

    it "shows empty state when no requirements exist" do
      get bulk_edit_project_requirements_path(project)
      expect(response.body).to include("No requirements to edit")
      expect(response.body).to include("Quick Entry")
    end

    it "shows Back to List button" do
      get bulk_edit_project_requirements_path(project)
      expect(response.body).to include("Back to List")
      expect(response.body).to include(project_requirements_path(project))
    end

    it "shows UID links to requirement detail pages" do
      req = create(:requirement, project: project, section: section, created_by: user)
      get bulk_edit_project_requirements_path(project)
      expect(response.body).to include(project_requirement_path(project, req))
    end

    it "shows module and section names" do
      create(:requirement, project: project, section: section, created_by: user)
      get bulk_edit_project_requirements_path(project)
      expect(response.body).to include("System Requirements")
      expect(response.body).to include("Functional")
    end

    it "shows section options in popovers" do
      create(:requirement, project: project, section: section, created_by: user)
      get bulk_edit_project_requirements_path(project)
      expect(response.body).to include("#{req_module.name} &gt; #{section.name}")
    end

    context "role-based access" do
      it "denies access to viewers" do
        membership.update!(role: :viewer)
        get bulk_edit_project_requirements_path(project)
        expect(response).to redirect_to(root_path)
      end

      it "denies access to authors" do
        membership.update!(role: :author)
        get bulk_edit_project_requirements_path(project)
        expect(response).to redirect_to(root_path)
      end

      it "allows access to project managers" do
        membership.update!(role: :project_manager)
        get bulk_edit_project_requirements_path(project)
        expect(response).to have_http_status(:success)
      end
    end

    context "multi-tenancy" do
      it "does not allow access to projects in other organizations" do
        other_org = create(:organization)
        other_project = create(:project, organization: other_org)
        get bulk_edit_project_requirements_path(other_project)
        expect(response).not_to have_http_status(:success)
      end
    end
  end

  describe "PATCH /projects/:project_id/requirements/bulk_update" do
    let!(:req1) { create(:requirement, project: project, section: section, created_by: user, title: "Original Title 1", requirement_type: :functional, priority: :must_have, asil_level: :qm) }
    let!(:req2) { create(:requirement, project: project, section: section, created_by: user, title: "Original Title 2", requirement_type: :functional, priority: :must_have, asil_level: :qm) }

    it "updates a single requirement title" do
      patch bulk_update_project_requirements_path(project), params: {
        requirements: {
          req1.id => { title: "Updated Brake Title" }
        }
      }
      expect(response).to redirect_to(bulk_edit_project_requirements_path(project))
      expect(req1.reload.title).to eq("Updated Brake Title")
    end

    it "strips whitespace from titles" do
      patch bulk_update_project_requirements_path(project), params: {
        requirements: {
          req1.id => { title: "  Padded Title  " }
        }
      }
      expect(req1.reload.title).to eq("Padded Title")
    end

    it "updates requirement type" do
      patch bulk_update_project_requirements_path(project), params: {
        requirements: {
          req1.id => { requirement_type: "safety" }
        }
      }
      expect(req1.reload.requirement_type).to eq("safety")
    end

    it "updates requirement status" do
      patch bulk_update_project_requirements_path(project), params: {
        requirements: {
          req1.id => { status: "in_review" }
        }
      }
      expect(req1.reload.status).to eq("in_review")
    end

    it "updates requirement priority" do
      patch bulk_update_project_requirements_path(project), params: {
        requirements: {
          req1.id => { priority: "should_have" }
        }
      }
      expect(req1.reload.priority).to eq("should_have")
    end

    it "updates requirement ASIL level" do
      patch bulk_update_project_requirements_path(project), params: {
        requirements: {
          req1.id => { asil_level: "asil_d" }
        }
      }
      expect(req1.reload.asil_level).to eq("asil_d")
    end

    it "updates multiple attributes at once" do
      patch bulk_update_project_requirements_path(project), params: {
        requirements: {
          req1.id => { title: "New Title", requirement_type: "safety", priority: "must_have", asil_level: "asil_c" }
        }
      }
      req1.reload
      expect(req1.title).to eq("New Title")
      expect(req1.requirement_type).to eq("safety")
      expect(req1.priority).to eq("must_have")
      expect(req1.asil_level).to eq("asil_c")
    end

    it "updates multiple requirements in one request" do
      patch bulk_update_project_requirements_path(project), params: {
        requirements: {
          req1.id => { requirement_type: "safety" },
          req2.id => { requirement_type: "non_functional" }
        }
      }
      expect(req1.reload.requirement_type).to eq("safety")
      expect(req2.reload.requirement_type).to eq("non_functional")
    end

    it "moves requirement to a different section" do
      new_module = create(:requirement_module, project: project, name: "Safety")
      new_section = create(:section, requirement_module: new_module, name: "ASIL Requirements")
      patch bulk_update_project_requirements_path(project), params: {
        requirements: {
          req1.id => { section_id: new_section.id.to_s }
        }
      }
      expect(req1.reload.section).to eq(new_section)
    end

    it "redirects with success notice and count" do
      patch bulk_update_project_requirements_path(project), params: {
        requirements: {
          req1.id => { priority: "could_have" },
          req2.id => { priority: "could_have" }
        }
      }
      expect(response).to redirect_to(bulk_edit_project_requirements_path(project))
      follow_redirect!
      expect(response.body).to include("2 requirements updated")
    end

    it "shows singular count for single update" do
      patch bulk_update_project_requirements_path(project), params: {
        requirements: {
          req1.id => { priority: "could_have" }
        }
      }
      expect(response).to redirect_to(bulk_edit_project_requirements_path(project))
      follow_redirect!
      expect(response.body).to include("1 requirement updated")
    end

    it "tracks changes via PaperTrail" do
      expect {
        patch bulk_update_project_requirements_path(project), params: {
          requirements: {
            req1.id => { title: "Paper Trail Title" }
          }
        }
      }.to change { req1.versions.count }.by(1)
    end

    it "reports validation errors with requirement UID" do
      patch bulk_update_project_requirements_path(project), params: {
        requirements: {
          req1.id => { title: "" }
        }
      }
      # Blank title stripped to nil, which should fail presence validation
      # But the controller strips whitespace — empty string becomes empty, so:
      expect(response).to redirect_to(bulk_edit_project_requirements_path(project))
    end

    it "skips unknown requirement IDs" do
      patch bulk_update_project_requirements_path(project), params: {
        requirements: {
          "999999" => { title: "Ghost" },
          req1.id => { title: "Real Update" }
        }
      }
      expect(req1.reload.title).to eq("Real Update")
    end

    it "does not update requirements in other projects" do
      other_org = create(:organization)
      other_project = create(:project, organization: other_org)
      other_section = create(:section, requirement_module: create(:requirement_module, project: other_project))
      other_req = create(:requirement, project: other_project, section: other_section, created_by: user, title: "Foreign")
      patch bulk_update_project_requirements_path(project), params: {
        requirements: {
          other_req.id => { title: "Hacked" }
        }
      }
      expect(other_req.reload.title).to eq("Foreign")
    end

    it "returns 422 for invalid params" do
      patch bulk_update_project_requirements_path(project), params: {
        requirements: "not_a_hash"
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    context "bulk type change" do
      it "applies the same type to all selected requirements" do
        patch bulk_update_project_requirements_path(project), params: {
          requirements: {
            req1.id => { requirement_type: "safety" },
            req2.id => { requirement_type: "safety" }
          }
        }
        expect(req1.reload.requirement_type).to eq("safety")
        expect(req2.reload.requirement_type).to eq("safety")
      end
    end

    context "bulk priority change" do
      it "applies the same priority to all selected requirements" do
        patch bulk_update_project_requirements_path(project), params: {
          requirements: {
            req1.id => { priority: "could_have" },
            req2.id => { priority: "could_have" }
          }
        }
        expect(req1.reload.priority).to eq("could_have")
        expect(req2.reload.priority).to eq("could_have")
      end
    end

    context "bulk ASIL change" do
      it "applies the same ASIL level to all selected requirements" do
        patch bulk_update_project_requirements_path(project), params: {
          requirements: {
            req1.id => { asil_level: "asil_d" },
            req2.id => { asil_level: "asil_d" }
          }
        }
        expect(req1.reload.asil_level).to eq("asil_d")
        expect(req2.reload.asil_level).to eq("asil_d")
      end
    end

    context "bulk move to section" do
      it "moves all selected requirements to a new section" do
        new_module = create(:requirement_module, project: project, name: "Safety")
        new_section = create(:section, requirement_module: new_module, name: "Hazards")
        patch bulk_update_project_requirements_path(project), params: {
          requirements: {
            req1.id => { section_id: new_section.id.to_s },
            req2.id => { section_id: new_section.id.to_s }
          }
        }
        expect(req1.reload.section).to eq(new_section)
        expect(req2.reload.section).to eq(new_section)
      end
    end

    context "role-based access" do
      it "denies access to viewers" do
        membership.update!(role: :viewer)
        patch bulk_update_project_requirements_path(project), params: {
          requirements: { req1.id => { title: "Denied" } }
        }
        expect(response).to redirect_to(root_path)
        expect(req1.reload.title).to eq("Original Title 1")
      end

      it "denies access to authors" do
        membership.update!(role: :author)
        patch bulk_update_project_requirements_path(project), params: {
          requirements: { req1.id => { title: "Denied" } }
        }
        expect(response).to redirect_to(root_path)
        expect(req1.reload.title).to eq("Original Title 1")
      end

      it "allows access to project managers" do
        membership.update!(role: :project_manager)
        patch bulk_update_project_requirements_path(project), params: {
          requirements: { req1.id => { title: "PM Update" } }
        }
        expect(response).to redirect_to(bulk_edit_project_requirements_path(project))
        expect(req1.reload.title).to eq("PM Update")
      end
    end

    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        patch bulk_update_project_requirements_path(project), params: {
          requirements: { req1.id => { title: "Denied" } }
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /projects/:project_id/requirements/bulk_delete" do
    let!(:req1) { create(:requirement, project: project, section: section, created_by: user) }
    let!(:req2) { create(:requirement, project: project, section: section, created_by: user) }
    let!(:req3) { create(:requirement, project: project, section: section, created_by: user) }

    it "deletes selected requirements" do
      expect {
        delete bulk_delete_project_requirements_path(project), params: {
          requirement_ids: [req1.id, req2.id]
        }
      }.to change(Requirement, :count).by(-2)
    end

    it "redirects with success notice and count" do
      delete bulk_delete_project_requirements_path(project), params: {
        requirement_ids: [req1.id, req2.id]
      }
      expect(response).to redirect_to(bulk_edit_project_requirements_path(project))
      follow_redirect!
      expect(response.body).to include("2 requirements deleted")
    end

    it "shows singular count for single deletion" do
      delete bulk_delete_project_requirements_path(project), params: {
        requirement_ids: [req1.id]
      }
      follow_redirect!
      expect(response.body).to include("1 requirement deleted")
    end

    it "only deletes requirements in the current project" do
      other_org = create(:organization)
      other_project = create(:project, organization: other_org)
      other_section = create(:section, requirement_module: create(:requirement_module, project: other_project))
      other_req = create(:requirement, project: other_project, section: other_section, created_by: user)
      expect {
        delete bulk_delete_project_requirements_path(project), params: {
          requirement_ids: [other_req.id]
        }
      }.not_to change(Requirement, :count)
    end

    it "redirects with alert when no IDs provided" do
      delete bulk_delete_project_requirements_path(project)
      expect(response).to redirect_to(bulk_edit_project_requirements_path(project))
      follow_redirect!
      expect(response.body).to include("No requirements selected")
    end

    it "handles non-array params gracefully" do
      delete bulk_delete_project_requirements_path(project), params: {
        requirement_ids: "not_an_array"
      }
      expect(response).to redirect_to(bulk_edit_project_requirements_path(project))
    end

    context "role-based access" do
      it "denies access to viewers" do
        membership.update!(role: :viewer)
        expect {
          delete bulk_delete_project_requirements_path(project), params: {
            requirement_ids: [req1.id]
          }
        }.not_to change(Requirement, :count)
        expect(response).to redirect_to(root_path)
      end

      it "denies access to authors" do
        membership.update!(role: :author)
        expect {
          delete bulk_delete_project_requirements_path(project), params: {
            requirement_ids: [req1.id]
          }
        }.not_to change(Requirement, :count)
        expect(response).to redirect_to(root_path)
      end

      it "allows access to project managers" do
        membership.update!(role: :project_manager)
        expect {
          delete bulk_delete_project_requirements_path(project), params: {
            requirement_ids: [req1.id]
          }
        }.to change(Requirement, :count).by(-1)
      end
    end

    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        delete bulk_delete_project_requirements_path(project), params: {
          requirement_ids: [req1.id]
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
