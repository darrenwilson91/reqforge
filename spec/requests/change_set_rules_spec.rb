require "rails_helper"

RSpec.describe "ChangeSetRules", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user, organization: organization, role: :admin) }
  let(:project) { create(:project, organization: organization) }

  before { sign_in user }

  describe "GET /projects/:project_id/change_set_rules" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        get project_change_set_rules_path(project)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it "renders the settings page" do
      get project_change_set_rules_path(project)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Change Set Rules")
    end

    it "shows breadcrumbs" do
      get project_change_set_rules_path(project)
      expect(response.body).to include("Projects")
      expect(response.body).to include(project.name)
      expect(response.body).to include("Change Set Rules")
    end

    it "shows the project name" do
      get project_change_set_rules_path(project)
      expect(response.body).to include(project.name)
    end

    it "shows the approval requirements section" do
      get project_change_set_rules_path(project)
      expect(response.body).to include("Approval Requirements")
      expect(response.body).to include("min_approvals")
    end

    it "shows the conversation resolution section" do
      get project_change_set_rules_path(project)
      expect(response.body).to include("Conversation Resolution")
      expect(response.body).to include("require_all_conversations_resolved")
    end

    it "shows the auto-merge section" do
      get project_change_set_rules_path(project)
      expect(response.body).to include("Auto-Merge")
      expect(response.body).to include("auto_merge_on_approval")
    end

    it "shows the how merge rules work info" do
      get project_change_set_rules_path(project)
      expect(response.body).to include("How merge rules work")
    end

    it "shows Save and Cancel buttons" do
      get project_change_set_rules_path(project)
      expect(response.body).to include("Save Rules")
      expect(response.body).to include("Cancel")
    end

    it "shows Back to Change Sets link" do
      get project_change_set_rules_path(project)
      expect(response.body).to include("Back to Change Sets")
    end

    context "when a rule already exists" do
      let!(:rule) { create(:change_set_rule, project: project, min_approvals: 3) }

      it "renders with existing rule values" do
        get project_change_set_rules_path(project)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("3")
      end
    end

    context "when no rule exists" do
      it "shows default values" do
        get project_change_set_rules_path(project)
        expect(response).to have_http_status(:success)
        # Default min_approvals is 1
        expect(response.body).to include("1")
      end
    end

    context "role-based access" do
      it "denies viewers" do
        membership.update!(role: :viewer)
        get project_change_set_rules_path(project)
        expect(response).to redirect_to(root_path)
      end

      it "denies authors" do
        membership.update!(role: :author)
        get project_change_set_rules_path(project)
        expect(response).to redirect_to(root_path)
      end

      it "denies reviewers" do
        membership.update!(role: :reviewer)
        get project_change_set_rules_path(project)
        expect(response).to redirect_to(root_path)
      end

      it "allows project managers" do
        membership.update!(role: :project_manager)
        get project_change_set_rules_path(project)
        expect(response).to have_http_status(:success)
      end

      it "allows admins" do
        get project_change_set_rules_path(project)
        expect(response).to have_http_status(:success)
      end
    end

    context "multi-tenancy" do
      it "returns 404 for cross-org project" do
        other_org = create(:organization)
        other_project = create(:project, organization: other_org)
        get project_change_set_rules_path(other_project)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /projects/:project_id/change_set_rules" do
    context "when no rule exists" do
      it "creates a new rule" do
        expect {
          patch project_change_set_rules_path(project), params: {
            change_set_rule: { min_approvals: 2 }
          }
        }.to change(ChangeSetRule, :count).by(1)
      end

      it "saves the min_approvals value" do
        patch project_change_set_rules_path(project), params: {
          change_set_rule: { min_approvals: 3 }
        }
        expect(project.reload.change_set_rule.min_approvals).to eq(3)
      end

      it "saves the require_all_conversations_resolved value" do
        patch project_change_set_rules_path(project), params: {
          change_set_rule: {
            min_approvals: 1,
            require_all_conversations_resolved: "0"
          }
        }
        expect(project.reload.change_set_rule.require_all_conversations_resolved).to be false
      end

      it "saves the auto_merge_on_approval value" do
        patch project_change_set_rules_path(project), params: {
          change_set_rule: {
            min_approvals: 1,
            auto_merge_on_approval: "1"
          }
        }
        expect(project.reload.change_set_rule.auto_merge_on_approval).to be true
      end

      it "redirects with success notice" do
        patch project_change_set_rules_path(project), params: {
          change_set_rule: { min_approvals: 2 }
        }
        expect(response).to redirect_to(project_change_set_rules_path(project))
        follow_redirect!
        expect(response.body).to include("Change set rules updated successfully")
      end
    end

    context "when a rule already exists" do
      let!(:rule) { create(:change_set_rule, project: project, min_approvals: 1) }

      it "updates the existing rule" do
        expect {
          patch project_change_set_rules_path(project), params: {
            change_set_rule: { min_approvals: 4 }
          }
        }.not_to change(ChangeSetRule, :count)
        expect(rule.reload.min_approvals).to eq(4)
      end

      it "updates all three settings" do
        patch project_change_set_rules_path(project), params: {
          change_set_rule: {
            min_approvals: 5,
            require_all_conversations_resolved: "0",
            auto_merge_on_approval: "1"
          }
        }
        rule.reload
        expect(rule.min_approvals).to eq(5)
        expect(rule.require_all_conversations_resolved).to be false
        expect(rule.auto_merge_on_approval).to be true
      end
    end

    context "with invalid params" do
      it "rejects min_approvals of 0" do
        patch project_change_set_rules_path(project), params: {
          change_set_rule: { min_approvals: 0 }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects min_approvals of 11" do
        patch project_change_set_rules_path(project), params: {
          change_set_rule: { min_approvals: 11 }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "shows validation errors" do
        patch project_change_set_rules_path(project), params: {
          change_set_rule: { min_approvals: 0 }
        }
        expect(response.body).to include("error")
      end
    end

    context "role-based access" do
      it "denies viewers" do
        membership.update!(role: :viewer)
        patch project_change_set_rules_path(project), params: {
          change_set_rule: { min_approvals: 2 }
        }
        expect(response).to redirect_to(root_path)
      end

      it "denies authors" do
        membership.update!(role: :author)
        patch project_change_set_rules_path(project), params: {
          change_set_rule: { min_approvals: 2 }
        }
        expect(response).to redirect_to(root_path)
      end

      it "denies reviewers" do
        membership.update!(role: :reviewer)
        patch project_change_set_rules_path(project), params: {
          change_set_rule: { min_approvals: 2 }
        }
        expect(response).to redirect_to(root_path)
      end

      it "allows project managers" do
        membership.update!(role: :project_manager)
        patch project_change_set_rules_path(project), params: {
          change_set_rule: { min_approvals: 2 }
        }
        expect(response).to redirect_to(project_change_set_rules_path(project))
      end

      it "allows admins" do
        patch project_change_set_rules_path(project), params: {
          change_set_rule: { min_approvals: 2 }
        }
        expect(response).to redirect_to(project_change_set_rules_path(project))
      end
    end

    context "when not signed in" do
      before { sign_out user }

      it "redirects to sign in" do
        patch project_change_set_rules_path(project), params: {
          change_set_rule: { min_approvals: 2 }
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "merge_eligible? with unresolved conversations" do
    let!(:rule) do
      create(:change_set_rule,
             project: project,
             min_approvals: 1,
             require_all_conversations_resolved: true)
    end
    let(:change_set) { create(:change_set, project: project) }

    it "blocks merge when unresolved top-level comments exist" do
      create(:change_set_approval, :approved, change_set: change_set)
      create(:change_set_comment, change_set: change_set, user: user, resolved: false)
      expect(rule.merge_eligible?(change_set)).to be false
    end

    it "allows merge when all top-level comments are resolved" do
      create(:change_set_approval, :approved, change_set: change_set)
      create(:change_set_comment, change_set: change_set, user: user, resolved: true)
      expect(rule.merge_eligible?(change_set)).to be true
    end

    it "allows merge when no comments exist" do
      create(:change_set_approval, :approved, change_set: change_set)
      expect(rule.merge_eligible?(change_set)).to be true
    end

    it "allows merge when conversation resolution is not required" do
      rule.update!(require_all_conversations_resolved: false)
      create(:change_set_approval, :approved, change_set: change_set)
      create(:change_set_comment, change_set: change_set, user: user, resolved: false)
      expect(rule.merge_eligible?(change_set)).to be true
    end

    it "ignores reply comments (only checks top-level)" do
      create(:change_set_approval, :approved, change_set: change_set)
      parent = create(:change_set_comment, change_set: change_set, user: user, resolved: true)
      create(:change_set_comment, change_set: change_set, user: user, parent_comment: parent, resolved: false)
      expect(rule.merge_eligible?(change_set)).to be true
    end
  end
end
