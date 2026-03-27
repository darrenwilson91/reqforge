class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :organization

  enum :role, { admin: 0, project_manager: 1, author: 2, reviewer: 3, viewer: 4 }

  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :organization_id, message: "is already a member of this organization" }
end
