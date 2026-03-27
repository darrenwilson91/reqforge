# frozen_string_literal: true

require "rails_helper"

RSpec.describe TraceabilityLinkPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:project) { create(:project, organization: organization) }
  let(:req_module) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: req_module) }
  let(:source) { create(:requirement, project: project, section: section, created_by: admin_user) }
  let(:target) { create(:requirement, project: project, section: section, created_by: admin_user) }
  let(:link) { create(:traceability_link, source_requirement: source, target_requirement: target, created_by: admin_user) }

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
    it "allows all members" do
      %w[admin_user pm_user author_user reviewer_user viewer_user].each do |u|
        expect(subject.new(send(u), link)).to be_index
      end
    end

    it "denies non-member" do
      expect(subject.new(non_member_user, link)).not_to be_index
    end
  end

  describe "show?" do
    it "allows all members" do
      %w[admin_user pm_user author_user reviewer_user viewer_user].each do |u|
        expect(subject.new(send(u), link)).to be_show
      end
    end

    it "denies non-member" do
      expect(subject.new(non_member_user, link)).not_to be_show
    end
  end

  describe "create?" do
    it "allows admin" do
      expect(subject.new(admin_user, link)).to be_create
    end

    it "allows project manager" do
      expect(subject.new(pm_user, link)).to be_create
    end

    it "allows author" do
      expect(subject.new(author_user, link)).to be_create
    end

    it "denies reviewer" do
      expect(subject.new(reviewer_user, link)).not_to be_create
    end

    it "denies viewer" do
      expect(subject.new(viewer_user, link)).not_to be_create
    end

    it "denies non-member" do
      expect(subject.new(non_member_user, link)).not_to be_create
    end
  end

  describe "destroy?" do
    it "allows admin" do
      expect(subject.new(admin_user, link)).to be_destroy
    end

    it "allows project manager" do
      expect(subject.new(pm_user, link)).to be_destroy
    end

    it "denies author" do
      expect(subject.new(author_user, link)).not_to be_destroy
    end

    it "denies reviewer" do
      expect(subject.new(reviewer_user, link)).not_to be_destroy
    end

    it "denies viewer" do
      expect(subject.new(viewer_user, link)).not_to be_destroy
    end

    it "denies non-member" do
      expect(subject.new(non_member_user, link)).not_to be_destroy
    end
  end

  describe "cross-organization isolation" do
    let(:other_org) { create(:organization) }
    let(:other_project) { create(:project, organization: other_org) }
    let(:other_module) { create(:requirement_module, project: other_project) }
    let(:other_section) { create(:section, requirement_module: other_module) }
    let(:other_source) { create(:requirement, project: other_project, section: other_section, created_by: admin_user) }
    let(:other_target) { create(:requirement, project: other_project, section: other_section, created_by: admin_user) }
    let(:other_link) { create(:traceability_link, source_requirement: other_source, target_requirement: other_target, created_by: admin_user) }

    it "denies admin from org A access to links in org B" do
      expect(subject.new(admin_user, other_link)).not_to be_create
      expect(subject.new(admin_user, other_link)).not_to be_destroy
    end
  end
end
