class RequirementModule < ApplicationRecord
  belongs_to :project

  has_many :sections, dependent: :destroy
  has_many :requirements, through: :sections

  acts_as_list scope: :project

  validates :name, presence: true,
                   uniqueness: { scope: :project_id }
end
