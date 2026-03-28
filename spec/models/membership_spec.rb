require 'rails_helper'

RSpec.describe Membership, type: :model do
  subject { build(:membership) }

  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:organization) }
  end

  describe "validations" do
    it { should validate_presence_of(:role) }

    it "enforces unique user per organization" do
      existing = create(:membership)
      duplicate = build(:membership, user: existing.user, organization: existing.organization)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("is already a member of this organization")
    end

    it "allows the same user in different organizations" do
      user = create(:user)
      org1 = create(:organization)
      org2 = create(:organization)
      create(:membership, user: user, organization: org1)
      membership2 = build(:membership, user: user, organization: org2)
      expect(membership2).to be_valid
    end

    it "allows different users in the same organization" do
      org = create(:organization)
      create(:membership, user: create(:user), organization: org)
      membership2 = build(:membership, user: create(:user), organization: org)
      expect(membership2).to be_valid
    end
  end

  describe "role enum" do
    it { should define_enum_for(:role).with_values(admin: 0, project_manager: 1, author: 2, reviewer: 3, viewer: 4) }

    it "defaults to admin" do
      membership = Membership.new
      expect(membership.role).to eq("admin")
    end

    it "can be set to project_manager" do
      membership = build(:membership, :project_manager)
      expect(membership).to be_project_manager
    end

    it "can be set to author" do
      membership = build(:membership, :author)
      expect(membership).to be_author
    end

    it "can be set to reviewer" do
      membership = build(:membership, :reviewer)
      expect(membership).to be_reviewer
    end

    it "can be set to viewer" do
      membership = build(:membership, :viewer)
      expect(membership).to be_viewer
    end
  end

  describe "factory" do
    it "creates a valid membership" do
      membership = build(:membership)
      expect(membership).to be_valid
    end

    it "persists a membership" do
      membership = create(:membership)
      expect(membership).to be_persisted
    end
  end
end
