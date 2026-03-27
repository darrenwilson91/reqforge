# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:project) { create(:project, organization: organization) }

  let(:admin_user) { create(:user) }
  let(:pm_user) { create(:user) }
  let(:author_user) { create(:user) }
  let(:reviewer_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:non_member_user) { create(:user) }

  before do
    create(:membership, user: admin_user, organization: organization, role: :admin)
    create(:membership, user: pm_user, organization: organization, role: :project_manager)
    create(:membership, user: author_user, organization: organization, role: :author)
    create(:membership, user: reviewer_user, organization: organization, role: :reviewer)
    create(:membership, user: viewer_user, organization: organization, role: :viewer)
  end

  subject { described_class }

  describe "index?" do
    it "allows admin" do
      expect(subject.new(admin_user, project)).to be_index
    end

    it "allows project manager" do
      expect(subject.new(pm_user, project)).to be_index
    end

    it "allows author" do
      expect(subject.new(author_user, project)).to be_index
    end

    it "allows reviewer" do
      expect(subject.new(reviewer_user, project)).to be_index
    end

    it "allows viewer" do
      expect(subject.new(viewer_user, project)).to be_index
    end

    it "denies non-member" do
      expect(subject.new(non_member_user, project)).not_to be_index
    end
  end

  describe "show?" do
    it "allows all organization members" do
      [ admin_user, pm_user, author_user, reviewer_user, viewer_user ].each do |user|
        expect(subject.new(user, project)).to be_show
      end
    end

    it "denies non-member" do
      expect(subject.new(non_member_user, project)).not_to be_show
    end
  end

  describe "create?" do
    it "allows admin" do
      expect(subject.new(admin_user, project)).to be_create
    end

    it "allows project manager" do
      expect(subject.new(pm_user, project)).to be_create
    end

    it "denies author" do
      expect(subject.new(author_user, project)).not_to be_create
    end

    it "denies reviewer" do
      expect(subject.new(reviewer_user, project)).not_to be_create
    end

    it "denies viewer" do
      expect(subject.new(viewer_user, project)).not_to be_create
    end

    it "denies non-member" do
      expect(subject.new(non_member_user, project)).not_to be_create
    end
  end

  describe "new?" do
    it "delegates to create?" do
      expect(subject.new(admin_user, project)).to be_new
      expect(subject.new(viewer_user, project)).not_to be_new
    end
  end

  describe "update?" do
    it "allows admin" do
      expect(subject.new(admin_user, project)).to be_update
    end

    it "allows project manager" do
      expect(subject.new(pm_user, project)).to be_update
    end

    it "denies author" do
      expect(subject.new(author_user, project)).not_to be_update
    end

    it "denies reviewer" do
      expect(subject.new(reviewer_user, project)).not_to be_update
    end

    it "denies viewer" do
      expect(subject.new(viewer_user, project)).not_to be_update
    end

    it "denies non-member" do
      expect(subject.new(non_member_user, project)).not_to be_update
    end
  end

  describe "edit?" do
    it "delegates to update?" do
      expect(subject.new(pm_user, project)).to be_edit
      expect(subject.new(author_user, project)).not_to be_edit
    end
  end

  describe "destroy?" do
    it "allows admin" do
      expect(subject.new(admin_user, project)).to be_destroy
    end

    it "denies project manager" do
      expect(subject.new(pm_user, project)).not_to be_destroy
    end

    it "denies author" do
      expect(subject.new(author_user, project)).not_to be_destroy
    end

    it "denies reviewer" do
      expect(subject.new(reviewer_user, project)).not_to be_destroy
    end

    it "denies viewer" do
      expect(subject.new(viewer_user, project)).not_to be_destroy
    end

    it "denies non-member" do
      expect(subject.new(non_member_user, project)).not_to be_destroy
    end
  end

  describe "cross-organization isolation" do
    let(:other_org) { create(:organization) }
    let(:other_project) { create(:project, organization: other_org) }

    it "denies admin access to projects in other organizations" do
      expect(subject.new(admin_user, other_project)).not_to be_show
      expect(subject.new(admin_user, other_project)).not_to be_update
      expect(subject.new(admin_user, other_project)).not_to be_destroy
    end
  end
end
