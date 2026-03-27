require "rails_helper"

RSpec.describe "TraceabilityLinks", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization) }
  let(:req_module) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: req_module) }

  before { sign_in user }

  def create_req(**attrs)
    create(:requirement, project: project, section: section, created_by: user, **attrs)
  end

  describe "POST /projects/:project_id/traceability_links" do
    let(:source) { create_req(title: "Source Requirement") }
    let(:target) { create_req(title: "Target Requirement") }

    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        post project_traceability_links_path(project), params: {
          traceability_link: {
            source_requirement_id: source.id,
            target_requirement_id: target.id,
            link_type: "derives_from"
          }
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it "creates a traceability link with valid params" do
      expect {
        post project_traceability_links_path(project), params: {
          traceability_link: {
            source_requirement_id: source.id,
            target_requirement_id: target.id,
            link_type: "derives_from"
          }
        }
      }.to change(TraceabilityLink, :count).by(1)

      link = TraceabilityLink.last
      expect(link.source_requirement).to eq(source)
      expect(link.target_requirement).to eq(target)
      expect(link.link_type).to eq("derives_from")
      expect(link.created_by).to eq(user)
      expect(response).to redirect_to(project_requirement_path(project, source))
      follow_redirect!
      expect(response.body).to include("Traceability link created successfully")
    end

    it "creates a link with description" do
      post project_traceability_links_path(project), params: {
        traceability_link: {
          source_requirement_id: source.id,
          target_requirement_id: target.id,
          link_type: "satisfies",
          description: "Safety requirement satisfaction"
        }
      }
      expect(TraceabilityLink.last.description).to eq("Safety requirement satisfaction")
    end

    it "supports all link types" do
      TraceabilityLink.link_types.each_key do |link_type|
        src = create_req
        tgt = create_req
        post project_traceability_links_path(project), params: {
          traceability_link: {
            source_requirement_id: src.id,
            target_requirement_id: tgt.id,
            link_type: link_type
          }
        }
        expect(response).to redirect_to(project_requirement_path(project, src))
      end
    end

    it "rejects self-links" do
      post project_traceability_links_path(project), params: {
        traceability_link: {
          source_requirement_id: source.id,
          target_requirement_id: source.id,
          link_type: "derives_from"
        }
      }
      expect(response).to redirect_to(project_requirement_path(project, source))
      follow_redirect!
      expect(response.body).to include("cannot be the same as source requirement")
    end

    it "rejects duplicate links" do
      create(:traceability_link,
        source_requirement: source,
        target_requirement: target,
        link_type: :derives_from,
        created_by: user
      )

      post project_traceability_links_path(project), params: {
        traceability_link: {
          source_requirement_id: source.id,
          target_requirement_id: target.id,
          link_type: "derives_from"
        }
      }
      expect(response).to redirect_to(project_requirement_path(project, source))
      follow_redirect!
      expect(response.body).to include("already has this link type")
    end

    it "creates a PaperTrail version" do
      post project_traceability_links_path(project), params: {
        traceability_link: {
          source_requirement_id: source.id,
          target_requirement_id: target.id,
          link_type: "verifies"
        }
      }
      expect(TraceabilityLink.last.versions.count).to eq(1)
    end

    it "allows cross-project links within the same organization" do
      other_project = create(:project, organization: organization)
      other_module = create(:requirement_module, project: other_project)
      other_section = create(:section, requirement_module: other_module)
      other_req = create(:requirement, project: other_project, section: other_section, created_by: user, title: "Cross-project target")

      expect {
        post project_traceability_links_path(project), params: {
          traceability_link: {
            source_requirement_id: source.id,
            target_requirement_id: other_req.id,
            link_type: "derives_from"
          }
        }
      }.to change(TraceabilityLink, :count).by(1)
    end

    it "rejects target requirements from other organizations" do
      other_org = create(:organization)
      other_project = create(:project, organization: other_org)
      other_module = create(:requirement_module, project: other_project)
      other_section = create(:section, requirement_module: other_module)
      other_req = create(:requirement, project: other_project, section: other_section, created_by: user)

      expect {
        post project_traceability_links_path(project), params: {
          traceability_link: {
            source_requirement_id: source.id,
            target_requirement_id: other_req.id,
            link_type: "derives_from"
          }
        }
      }.not_to change(TraceabilityLink, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "rejects source requirements not in the project" do
      other_project = create(:project, organization: organization)
      other_module = create(:requirement_module, project: other_project)
      other_section = create(:section, requirement_module: other_module)
      foreign_source = create(:requirement, project: other_project, section: other_section, created_by: user)

      expect {
        post project_traceability_links_path(project), params: {
          traceability_link: {
            source_requirement_id: foreign_source.id,
            target_requirement_id: target.id,
            link_type: "derives_from"
          }
        }
      }.not_to change(TraceabilityLink, :count)
      expect(response).to have_http_status(:not_found)
    end

    context "role-based authorization" do
      it "allows authors to create links" do
        author = create(:user)
        create(:membership, user: author, organization: organization, role: :author)
        sign_in author

        expect {
          post project_traceability_links_path(project), params: {
            traceability_link: {
              source_requirement_id: source.id,
              target_requirement_id: target.id,
              link_type: "derives_from"
            }
          }
        }.to change(TraceabilityLink, :count).by(1)
      end

      it "allows project managers to create links" do
        pm = create(:user)
        create(:membership, user: pm, organization: organization, role: :project_manager)
        sign_in pm

        expect {
          post project_traceability_links_path(project), params: {
            traceability_link: {
              source_requirement_id: source.id,
              target_requirement_id: target.id,
              link_type: "derives_from"
            }
          }
        }.to change(TraceabilityLink, :count).by(1)
      end

      it "denies viewers from creating links" do
        viewer = create(:user)
        create(:membership, user: viewer, organization: organization, role: :viewer)
        sign_in viewer

        post project_traceability_links_path(project), params: {
          traceability_link: {
            source_requirement_id: source.id,
            target_requirement_id: target.id,
            link_type: "derives_from"
          }
        }
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("not authorized")
      end

      it "denies reviewers from creating links" do
        reviewer = create(:user)
        create(:membership, user: reviewer, organization: organization, role: :reviewer)
        sign_in reviewer

        post project_traceability_links_path(project), params: {
          traceability_link: {
            source_requirement_id: source.id,
            target_requirement_id: target.id,
            link_type: "derives_from"
          }
        }
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("not authorized")
      end
    end
  end

  describe "DELETE /projects/:project_id/traceability_links/:id" do
    let(:source) { create_req(title: "Source Req") }
    let(:target) { create_req(title: "Target Req") }
    let!(:link) do
      create(:traceability_link,
        source_requirement: source,
        target_requirement: target,
        link_type: :derives_from,
        created_by: user
      )
    end

    it "destroys the traceability link" do
      expect {
        delete project_traceability_link_path(project, link)
      }.to change(TraceabilityLink, :count).by(-1)

      expect(response).to redirect_to(project_requirement_path(project, source))
      follow_redirect!
      expect(response.body).to include("Traceability link removed")
    end

    it "redirects back to the source requirement" do
      delete project_traceability_link_path(project, link)
      expect(response).to redirect_to(project_requirement_path(project, source))
    end

    it "returns 404 for links not associated with the project" do
      other_org = create(:organization)
      other_project = create(:project, organization: other_org)
      other_module = create(:requirement_module, project: other_project)
      other_section = create(:section, requirement_module: other_module)
      other_source = create(:requirement, project: other_project, section: other_section, created_by: user)
      other_target = create(:requirement, project: other_project, section: other_section, created_by: user)
      other_link = create(:traceability_link,
        source_requirement: other_source,
        target_requirement: other_target,
        link_type: :derives_from,
        created_by: user
      )

      expect {
        delete project_traceability_link_path(project, other_link)
      }.not_to change(TraceabilityLink, :count)
      expect(response).to have_http_status(:not_found)
    end

    context "role-based authorization" do
      it "allows admins to delete links" do
        expect {
          delete project_traceability_link_path(project, link)
        }.to change(TraceabilityLink, :count).by(-1)
      end

      it "allows project managers to delete links" do
        pm = create(:user)
        create(:membership, user: pm, organization: organization, role: :project_manager)
        sign_in pm

        expect {
          delete project_traceability_link_path(project, link)
        }.to change(TraceabilityLink, :count).by(-1)
      end

      it "denies authors from deleting links" do
        author = create(:user)
        create(:membership, user: author, organization: organization, role: :author)
        sign_in author

        delete project_traceability_link_path(project, link)
        expect(response).to redirect_to(root_path)
        expect(TraceabilityLink.count).to eq(1)
      end

      it "denies viewers from deleting links" do
        viewer = create(:user)
        create(:membership, user: viewer, organization: organization, role: :viewer)
        sign_in viewer

        delete project_traceability_link_path(project, link)
        expect(response).to redirect_to(root_path)
        expect(TraceabilityLink.count).to eq(1)
      end
    end
  end
end
