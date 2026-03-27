require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  describe "Pundit integration" do
    it "includes Pundit::Authorization" do
      expect(described_class.ancestors).to include(Pundit::Authorization)
    end
  end

  describe "helper methods" do
    it "exposes current_organization as a helper method" do
      expect(described_class._helper_methods).to include(:current_organization)
    end

    it "exposes current_membership as a helper method" do
      expect(described_class._helper_methods).to include(:current_membership)
    end
  end
end
