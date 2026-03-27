class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations added when Membership/Organization models are generated
  # has_many :memberships, dependent: :destroy
  # has_many :organizations, through: :memberships

  validates :first_name, presence: true
  validates :last_name, presence: true

  def full_name
    "#{first_name} #{last_name}"
  end
end
