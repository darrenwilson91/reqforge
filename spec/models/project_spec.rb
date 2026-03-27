require 'rails_helper'

RSpec.describe Project, type: :model do
  subject { build(:project) }

  describe "associations" do
    it { should belong_to(:organization) }
    it { should have_many(:requirement_modules).dependent(:destroy) }
    it { should have_many(:requirements).dependent(:destroy) }
    it { should have_one(:change_set_rule).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).scoped_to(:organization_id) }
    it { should validate_presence_of(:prefix) }
    it { should validate_uniqueness_of(:prefix).scoped_to(:organization_id) }

    describe "prefix format" do
      it "allows uppercase letters and digits" do
        subject.prefix = "SWR01"
        expect(subject).to be_valid
      end

      it "allows hyphens and underscores" do
        subject.prefix = "SW-REQ"
        expect(subject).to be_valid
      end

      it "rejects lowercase letters" do
        subject.prefix = "swr"
        expect(subject).not_to be_valid
      end

      it "rejects prefix starting with a digit" do
        subject.prefix = "1PRJ"
        expect(subject).not_to be_valid
      end

      it "rejects prefix longer than 10 characters" do
        subject.prefix = "A" * 11
        expect(subject).not_to be_valid
      end

      it "allows a single uppercase letter" do
        subject.prefix = "R"
        expect(subject).to be_valid
      end
    end
  end

  describe "enums" do
    it { should define_enum_for(:status).with_values(active: 0, archived: 1, template: 2) }
  end

  describe "organization scoping" do
    it "includes OrganizationScoped concern" do
      expect(Project.ancestors).to include(OrganizationScoped)
    end

    it "scopes projects by organization" do
      org1 = create(:organization)
      org2 = create(:organization)
      project1 = create(:project, organization: org1)
      _project2 = create(:project, organization: org2)

      expect(Project.for_organization(org1)).to contain_exactly(project1)
    end
  end

  describe "attribute_schema" do
    it "defaults to an empty hash" do
      project = create(:project)
      expect(project.attribute_schema).to eq({})
    end

    it "stores custom attribute definitions as JSON" do
      project = create(:project, :with_custom_attributes)
      project.reload
      expect(project.attribute_schema["attributes"]).to be_an(Array)
      expect(project.attribute_schema["attributes"].first["name"]).to eq("Safety Classification")
    end
  end

  describe "factory" do
    it "creates a valid project" do
      expect(build(:project)).to be_valid
    end

    it "persists a project" do
      project = create(:project)
      expect(project).to be_persisted
    end

    it "creates an archived project" do
      project = create(:project, :archived)
      expect(project).to be_archived
    end

    it "creates a project with custom attributes" do
      project = create(:project, :with_custom_attributes)
      expect(project.attribute_schema["attributes"].length).to eq(2)
    end
  end
end
