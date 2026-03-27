# frozen_string_literal: true

class ProjectPolicy < ApplicationPolicy
  def index?
    membership.present?
  end

  def show?
    membership.present?
  end

  def create?
    membership&.admin? || membership&.project_manager?
  end

  def update?
    membership&.admin? || membership&.project_manager?
  end

  def destroy?
    membership&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if membership.present?
        scope.for_organization(organization)
      else
        scope.none
      end
    end

    private

    def organization
      user.organizations.first # Overridden by controller context
    end

    def membership
      user.memberships.find_by(organization: organization)
    end
  end

  private

  def membership
    return nil unless user && record

    organization = record.respond_to?(:organization) ? record.organization : nil
    return nil unless organization

    @membership ||= user.memberships.find_by(organization: organization)
  end
end
