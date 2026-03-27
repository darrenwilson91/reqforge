module OrganizationScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :organization

    scope :for_organization, ->(organization) {
      where(organization: organization) if organization
    }
  end
end
