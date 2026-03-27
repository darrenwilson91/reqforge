class Organization < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :projects, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true,
                   uniqueness: true,
                   format: { with: /\A[a-z0-9][a-z0-9-]*[a-z0-9]\z/,
                             message: "must be lowercase alphanumeric with hyphens, and cannot start or end with a hyphen",
                             allow_blank: true }

  before_validation :generate_slug, on: :create, if: -> { slug.blank? && name.present? }

  private

  def generate_slug
    base_slug = name.parameterize
    candidate = base_slug
    counter = 1

    while Organization.exists?(slug: candidate)
      candidate = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = candidate
  end
end
