class Project < ApplicationRecord
  include OrganizationScoped

  has_many :requirement_modules, dependent: :destroy
  has_many :requirements, dependent: :destroy

  enum :status, { active: 0, archived: 1, template: 2 }

  validates :name, presence: true,
                   uniqueness: { scope: :organization_id }
  validates :prefix, presence: true,
                     uniqueness: { scope: :organization_id },
                     format: { with: /\A[A-Z][A-Z0-9_-]{0,9}\z/,
                               message: "must start with an uppercase letter, contain only uppercase letters/digits/hyphens/underscores, and be 1-10 characters",
                               allow_blank: true }
end
