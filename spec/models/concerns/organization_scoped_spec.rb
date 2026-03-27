require "rails_helper"

RSpec.describe OrganizationScoped, type: :model do
  # Create a temporary table and named model to test the concern in isolation
  before(:all) do
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Schema.define do
        create_table :scoped_test_resources, force: true do |t|
          t.references :organization, null: false
          t.string :name
          t.timestamps
        end
      end
    end

    # Define a named model class so ActiveRecord reflection works
    Object.const_set(:ScopedTestResource, Class.new(ApplicationRecord) {
      self.table_name = "scoped_test_resources"
      include OrganizationScoped
    }) unless Object.const_defined?(:ScopedTestResource)
  end

  after(:all) do
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Schema.define do
        drop_table :scoped_test_resources, if_exists: true
      end
    end
    Object.send(:remove_const, :ScopedTestResource) if Object.const_defined?(:ScopedTestResource)
  end

  let(:org_a) { create(:organization, name: "Org A") }
  let(:org_b) { create(:organization, name: "Org B") }

  describe "associations" do
    it "belongs to an organization" do
      resource = ScopedTestResource.new(organization: org_a, name: "Test")
      expect(resource.organization).to eq(org_a)
    end

    it "requires an organization" do
      resource = ScopedTestResource.new(name: "No Org")
      expect(resource).not_to be_valid
      expect(resource.errors[:organization]).to include("must exist")
    end
  end

  describe ".for_organization" do
    let!(:resource_a1) { ScopedTestResource.create!(organization: org_a, name: "A1") }
    let!(:resource_a2) { ScopedTestResource.create!(organization: org_a, name: "A2") }
    let!(:resource_b1) { ScopedTestResource.create!(organization: org_b, name: "B1") }

    it "returns only records for the given organization" do
      results = ScopedTestResource.for_organization(org_a)
      expect(results).to contain_exactly(resource_a1, resource_a2)
    end

    it "excludes records from other organizations" do
      results = ScopedTestResource.for_organization(org_a)
      expect(results).not_to include(resource_b1)
    end

    it "returns all records when passed nil" do
      results = ScopedTestResource.for_organization(nil)
      expect(results).to contain_exactly(resource_a1, resource_a2, resource_b1)
    end

    it "returns empty relation when organization has no records" do
      org_c = create(:organization, name: "Org C")
      results = ScopedTestResource.for_organization(org_c)
      expect(results).to be_empty
    end

    it "is chainable with other scopes" do
      results = ScopedTestResource.for_organization(org_a).where(name: "A1")
      expect(results).to contain_exactly(resource_a1)
    end
  end
end
