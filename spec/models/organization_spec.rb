require 'rails_helper'

RSpec.describe Organization, type: :model do
  subject { build(:organization) }

  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:slug) }

    it "requires slug when name is also blank" do
      org = Organization.new(name: nil, slug: nil)
      expect(org).not_to be_valid
      expect(org.errors[:slug]).to include("can't be blank")
    end

    describe "slug format" do
      it "allows lowercase alphanumeric with hyphens" do
        subject.slug = "my-org-123"
        expect(subject).to be_valid
      end

      it "rejects slugs starting with a hyphen" do
        subject.slug = "-my-org"
        expect(subject).not_to be_valid
      end

      it "rejects slugs ending with a hyphen" do
        subject.slug = "my-org-"
        expect(subject).not_to be_valid
      end

      it "rejects slugs with uppercase letters" do
        subject.slug = "My-Org"
        expect(subject).not_to be_valid
      end

      it "rejects slugs with spaces" do
        subject.slug = "my org"
        expect(subject).not_to be_valid
      end
    end
  end

  describe "associations" do
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:users).through(:memberships) }
    pending "has_many projects (Project model not yet generated)"
  end

  describe "slug generation" do
    it "auto-generates slug from name on create" do
      org = Organization.create!(name: "Acme Corporation")
      expect(org.slug).to eq("acme-corporation")
    end

    it "does not overwrite an explicitly provided slug" do
      org = Organization.create!(name: "Acme Corporation", slug: "custom-slug")
      expect(org.slug).to eq("custom-slug")
    end

    it "appends a counter when slug already exists" do
      Organization.create!(name: "Acme Corp", slug: "acme-corp")
      org2 = Organization.create!(name: "Acme Corp")
      expect(org2.slug).to eq("acme-corp-1")
    end

    it "does not regenerate slug on update" do
      org = Organization.create!(name: "Acme Corporation")
      org.update!(name: "New Name")
      expect(org.slug).to eq("acme-corporation")
    end
  end

  describe "settings" do
    it "defaults to an empty hash" do
      org = Organization.create!(name: "Test Org")
      expect(org.settings).to eq({})
    end

    it "stores arbitrary settings as JSON" do
      org = Organization.create!(name: "Test Org", settings: { "theme" => "dark", "max_projects" => 10 })
      org.reload
      expect(org.settings).to eq({ "theme" => "dark", "max_projects" => 10 })
    end
  end

  describe "factory" do
    it "creates a valid organization" do
      org = build(:organization)
      expect(org).to be_valid
    end

    it "persists an organization" do
      org = create(:organization)
      expect(org).to be_persisted
      expect(org.slug).to be_present
    end
  end
end
