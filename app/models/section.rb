class Section < ApplicationRecord
  belongs_to :requirement_module
  belongs_to :parent_section, class_name: "Section", optional: true

  has_many :child_sections, class_name: "Section",
                            foreign_key: :parent_section_id,
                            dependent: :destroy
  # has_many :requirements, dependent: :destroy — added when Requirement model is generated

  acts_as_list scope: [:requirement_module_id, :parent_section_id]

  validates :name, presence: true,
                   uniqueness: { scope: [:requirement_module_id, :parent_section_id] }
end
