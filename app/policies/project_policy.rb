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
      org = context_organization || user.organizations.first
      if org && user.memberships.exists?(organization: org)
        scope.for_organization(org)
      else
        scope.none
      end
    end
  end

  private

  def membership
    return nil unless user

    # For instance records, use the record's organization
    # For class records (index?, create?), use the context organization
    org = if record.respond_to?(:organization) && record.try(:organization)
      record.organization
    else
      context_organization
    end

    return nil unless org

    @membership ||= user.memberships.find_by(organization: org)
  end
end
