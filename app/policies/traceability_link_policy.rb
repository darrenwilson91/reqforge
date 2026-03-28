# frozen_string_literal: true

class TraceabilityLinkPolicy < ApplicationPolicy
  # All org members can view links
  def index?
    membership.present?
  end

  def show?
    membership.present?
  end

  # Authors, PMs, and admins can create links
  def create?
    membership&.admin? || membership&.project_manager? || membership&.author?
  end

  # Only PMs and admins can delete links
  def destroy?
    membership&.admin? || membership&.project_manager?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  private

  def membership
    return nil unless user

    org = if record.respond_to?(:source_requirement) && record.try(:source_requirement)&.project&.organization
      record.source_requirement.project.organization
    else
      context_organization
    end

    return nil unless org

    @membership ||= user.memberships.find_by(organization: org)
  end
end
