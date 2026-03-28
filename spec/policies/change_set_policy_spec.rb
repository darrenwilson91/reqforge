require "rails_helper"

RSpec.describe ChangeSetPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:project) { create(:project, organization: organization) }
  let(:admin_user) { create(:user) }
  let(:pm_user) { create(:user) }
  let(:author_user) { create(:user) }
  let(:reviewer_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:non_member) { create(:user) }

  before do
    create(:membership, user: admin_user, organization: organization, role: :admin)
    create(:membership, user: pm_user, organization: organization, role: :project_manager)
    create(:membership, user: author_user, organization: organization, role: :author)
    create(:membership, user: reviewer_user, organization: organization, role: :reviewer)
    create(:membership, user: viewer_user, organization: organization, role: :viewer)
  end

  let(:change_set) { create(:change_set, project: project, created_by: author_user) }

  describe "index?" do
    it "allows all members" do
      [ admin_user, pm_user, author_user, reviewer_user, viewer_user ].each do |u|
        expect(described_class.new(u, change_set).index?).to be true
      end
    end

    it "denies non-members" do
      expect(described_class.new(non_member, change_set).index?).to be false
    end
  end

  describe "show?" do
    it "allows all members" do
      [ admin_user, pm_user, author_user, reviewer_user, viewer_user ].each do |u|
        expect(described_class.new(u, change_set).show?).to be true
      end
    end

    it "denies non-members" do
      expect(described_class.new(non_member, change_set).show?).to be false
    end
  end

  describe "create?" do
    it "allows admin, PM, author" do
      [ admin_user, pm_user, author_user ].each do |u|
        expect(described_class.new(u, change_set).create?).to be true
      end
    end

    it "denies reviewer and viewer" do
      [ reviewer_user, viewer_user ].each do |u|
        expect(described_class.new(u, change_set).create?).to be false
      end
    end

    it "denies non-members" do
      expect(described_class.new(non_member, change_set).create?).to be_falsey
    end
  end

  describe "update?" do
    it "allows admin and PM regardless of creator" do
      [ admin_user, pm_user ].each do |u|
        expect(described_class.new(u, change_set).update?).to be true
      end
    end

    it "allows the creator" do
      expect(described_class.new(author_user, change_set).update?).to be true
    end

    it "denies non-creator author" do
      other_author = create(:user)
      create(:membership, user: other_author, organization: organization, role: :author)
      expect(described_class.new(other_author, change_set).update?).to be false
    end

    it "denies reviewer and viewer" do
      [ reviewer_user, viewer_user ].each do |u|
        expect(described_class.new(u, change_set).update?).to be false
      end
    end
  end

  describe "destroy?" do
    it "allows admin and PM" do
      [ admin_user, pm_user ].each do |u|
        expect(described_class.new(u, change_set).destroy?).to be true
      end
    end

    it "denies author, reviewer, viewer" do
      [ author_user, reviewer_user, viewer_user ].each do |u|
        expect(described_class.new(u, change_set).destroy?).to be false
      end
    end
  end

  describe "approve?" do
    it "denies the creator" do
      expect(described_class.new(author_user, change_set).approve?).to be false
    end

    it "allows other admin, PM, author, reviewer" do
      [ admin_user, pm_user, reviewer_user ].each do |u|
        expect(described_class.new(u, change_set).approve?).to be true
      end
    end

    it "denies viewer" do
      expect(described_class.new(viewer_user, change_set).approve?).to be false
    end

    it "denies non-member" do
      expect(described_class.new(non_member, change_set).approve?).to be false
    end
  end

  describe "merge?" do
    it "allows admin and PM" do
      [ admin_user, pm_user ].each do |u|
        expect(described_class.new(u, change_set).merge?).to be true
      end
    end

    it "denies author, reviewer, viewer" do
      [ author_user, reviewer_user, viewer_user ].each do |u|
        expect(described_class.new(u, change_set).merge?).to be false
      end
    end
  end

  describe "cross-organization isolation" do
    it "denies access from other org admin" do
      other_org = create(:organization)
      other_admin = create(:user)
      create(:membership, user: other_admin, organization: other_org, role: :admin)
      expect(described_class.new(other_admin, change_set).show?).to be false
      expect(described_class.new(other_admin, change_set).create?).to be_falsey
      expect(described_class.new(other_admin, change_set).approve?).to be false
      expect(described_class.new(other_admin, change_set).merge?).to be_falsey
    end
  end
end
