require "rails_helper"

RSpec.describe "ChangeSetComments", type: :request do
  let(:organization) { create(:organization) }
  let(:admin) { create(:user) }
  let(:reviewer) { create(:user) }
  let(:viewer) { create(:user) }
  let!(:admin_membership) { create(:membership, :admin, user: admin, organization: organization) }
  let!(:reviewer_membership) { create(:membership, :reviewer, user: reviewer, organization: organization) }
  let!(:viewer_membership) { create(:membership, :viewer, user: viewer, organization: organization) }
  let(:project) { create(:project, organization: organization) }
  let(:change_set) { create(:change_set, project: project, created_by: admin) }
  let(:section) { create(:section, requirement_module: create(:requirement_module, project: project)) }
  let(:requirement) { create(:requirement, project: project, section: section, created_by: admin) }
  let!(:cs_change) { create(:change_set_change, change_set: change_set, requirement: requirement) }

  describe "POST /projects/:project_id/change_sets/:change_set_id/change_set_comments" do
    context "when authenticated" do
      before { sign_in admin }

      it "creates a conversation comment (no change)" do
        expect {
          post project_change_set_change_set_comments_path(project, change_set),
            params: { change_set_comment: { body: "General feedback" } }
        }.to change(ChangeSetComment, :count).by(1)

        comment = ChangeSetComment.last
        expect(comment.body).to eq("General feedback")
        expect(comment.user).to eq(admin)
        expect(comment.change_set).to eq(change_set)
        expect(comment.change_set_change).to be_nil
      end

      it "creates an inline comment on a change" do
        expect {
          post project_change_set_change_set_comments_path(project, change_set),
            params: { change_set_comment: { body: "This change looks good", change_set_change_id: cs_change.id } }
        }.to change(ChangeSetComment, :count).by(1)

        comment = ChangeSetComment.last
        expect(comment.change_set_change).to eq(cs_change)
      end

      it "creates a threaded reply" do
        parent = create(:change_set_comment, change_set: change_set, user: reviewer)

        expect {
          post project_change_set_change_set_comments_path(project, change_set),
            params: { change_set_comment: { body: "Good point", parent_comment_id: parent.id } }
        }.to change(ChangeSetComment, :count).by(1)

        reply = ChangeSetComment.last
        expect(reply.parent_comment).to eq(parent)
      end

      it "redirects with anchor on success" do
        post project_change_set_change_set_comments_path(project, change_set),
          params: { change_set_comment: { body: "Test comment" } }

        comment = ChangeSetComment.last
        expect(response).to redirect_to(project_change_set_path(project, change_set, anchor: "comment-#{comment.id}"))
      end

      it "rejects blank body" do
        post project_change_set_change_set_comments_path(project, change_set),
          params: { change_set_comment: { body: "" } }

        expect(response).to redirect_to(project_change_set_path(project, change_set))
        expect(flash[:alert]).to be_present
      end

      it "assigns the current user" do
        post project_change_set_change_set_comments_path(project, change_set),
          params: { change_set_comment: { body: "My comment" } }

        expect(ChangeSetComment.last.user).to eq(admin)
      end
    end

    context "as a reviewer" do
      before { sign_in reviewer }

      it "can create comments" do
        expect {
          post project_change_set_change_set_comments_path(project, change_set),
            params: { change_set_comment: { body: "Reviewer comment" } }
        }.to change(ChangeSetComment, :count).by(1)
      end
    end

    context "as a viewer" do
      before { sign_in viewer }

      it "can create comments" do
        expect {
          post project_change_set_change_set_comments_path(project, change_set),
            params: { change_set_comment: { body: "Viewer comment" } }
        }.to change(ChangeSetComment, :count).by(1)
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        post project_change_set_change_set_comments_path(project, change_set),
          params: { change_set_comment: { body: "Unauthorized" } }

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /projects/:project_id/change_sets/:change_set_id/change_set_comments/:id/resolve" do
    let!(:comment) { create(:change_set_comment, change_set: change_set, user: reviewer) }

    context "when authenticated" do
      before { sign_in admin }

      it "resolves the comment" do
        patch resolve_project_change_set_change_set_comment_path(project, change_set, comment)

        comment.reload
        expect(comment.resolved).to be true
        expect(comment.resolved_by).to eq(admin)
        expect(comment.resolved_at).to be_present
      end

      it "redirects with anchor" do
        patch resolve_project_change_set_change_set_comment_path(project, change_set, comment)

        expect(response).to redirect_to(project_change_set_path(project, change_set, anchor: "comment-#{comment.id}"))
      end
    end
  end

  describe "PATCH /projects/:project_id/change_sets/:change_set_id/change_set_comments/:id/unresolve" do
    let!(:comment) { create(:change_set_comment, :resolved, change_set: change_set, user: reviewer) }

    context "when authenticated" do
      before { sign_in admin }

      it "unresolves the comment" do
        patch unresolve_project_change_set_change_set_comment_path(project, change_set, comment)

        comment.reload
        expect(comment.resolved).to be false
        expect(comment.resolved_by).to be_nil
      end

      it "redirects with anchor" do
        patch unresolve_project_change_set_change_set_comment_path(project, change_set, comment)

        expect(response).to redirect_to(project_change_set_path(project, change_set, anchor: "comment-#{comment.id}"))
      end
    end
  end

  describe "change set show page with comments" do
    before { sign_in admin }

    it "shows the Changes tab" do
      get project_change_set_path(project, change_set)
      expect(response.body).to include("Changes")
    end

    it "shows the Conversation tab" do
      get project_change_set_path(project, change_set)
      expect(response.body).to include("Conversation")
    end

    it "shows inline comment form on each change" do
      get project_change_set_path(project, change_set)
      expect(response.body).to include("Add a comment on this change")
    end

    it "shows conversation comment form" do
      get project_change_set_path(project, change_set)
      expect(response.body).to include("Leave a comment")
    end

    it "shows existing inline comments" do
      comment = create(:change_set_comment, change_set: change_set, change_set_change: cs_change,
        user: reviewer, body: "This looks problematic")

      get project_change_set_path(project, change_set)
      expect(response.body).to include("This looks problematic")
      expect(response.body).to include(reviewer.full_name)
    end

    it "shows existing conversation comments" do
      create(:change_set_comment, change_set: change_set, change_set_change: nil,
        user: reviewer, body: "General thoughts on this change set")

      get project_change_set_path(project, change_set)
      expect(response.body).to include("General thoughts on this change set")
    end

    it "shows the comments stat card with count" do
      create(:change_set_comment, change_set: change_set, user: reviewer)

      get project_change_set_path(project, change_set)
      expect(response.body).to include("Comments")
    end

    it "shows unresolved count in stats" do
      create(:change_set_comment, change_set: change_set, user: reviewer)
      create(:change_set_comment, :resolved, change_set: change_set, user: admin)

      get project_change_set_path(project, change_set)
      expect(response.body).to include("1 unresolved")
    end

    it "shows resolve/unresolve actions on comments" do
      create(:change_set_comment, change_set: change_set, user: reviewer, body: "Needs fix")

      get project_change_set_path(project, change_set)
      expect(response.body).to include("Resolve")
    end

    it "shows resolved badge on resolved comments" do
      create(:change_set_comment, :resolved, change_set: change_set, user: reviewer, body: "Fixed")

      get project_change_set_path(project, change_set)
      expect(response.body).to include("Resolved")
      expect(response.body).to include("Reopen")
    end

    it "shows threaded replies" do
      parent = create(:change_set_comment, change_set: change_set, user: reviewer, body: "Parent comment")
      create(:change_set_comment, change_set: change_set, user: admin, body: "Reply to parent",
        parent_comment: parent)

      get project_change_set_path(project, change_set)
      expect(response.body).to include("Parent comment")
      expect(response.body).to include("Reply to parent")
    end

    it "hides comment forms on merged change sets" do
      merged_cs = create(:change_set, :merged, project: project, created_by: admin)

      get project_change_set_path(project, merged_cs)
      expect(response.body).not_to include("Add a comment on this change")
      expect(response.body).not_to include("Leave a comment")
    end

    it "shows conversation empty state" do
      get project_change_set_path(project, change_set)
      expect(response.body).to include("No conversation yet")
    end
  end
end
