require 'rails_helper'

RSpec.describe User, type: :model do
  subject { build(:user) }

  describe "validations" do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:password) }
    it { should validate_uniqueness_of(:email).case_insensitive }
  end

  describe "associations" do
    # These will pass once Membership and Organization models are generated
    pending "has_many memberships (Membership model not yet generated)"
    pending "has_many organizations through memberships (Organization model not yet generated)"
  end

  describe "#full_name" do
    it "returns first and last name combined" do
      user = build(:user, first_name: "Jane", last_name: "Doe")
      expect(user.full_name).to eq("Jane Doe")
    end
  end

  describe "devise modules" do
    it "is database authenticatable" do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it "is registerable" do
      expect(User.devise_modules).to include(:registerable)
    end

    it "is recoverable" do
      expect(User.devise_modules).to include(:recoverable)
    end

    it "is rememberable" do
      expect(User.devise_modules).to include(:rememberable)
    end

    it "is validatable" do
      expect(User.devise_modules).to include(:validatable)
    end
  end

  describe "factory" do
    it "creates a valid user" do
      user = build(:user)
      expect(user).to be_valid
    end

    it "persists a user" do
      user = create(:user)
      expect(user).to be_persisted
    end
  end
end
