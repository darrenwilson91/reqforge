# frozen_string_literal: true

class TestCasePolicy < ApplicationPolicy
  def index?
    membership.present?
  end

  def show?
    membership.present?
  end

  def create?
    membership&.admin? || membership&.project_manager? || membership&.author?
  end

  def update?
    membership&.admin? || membership&.project_manager? || membership&.author?
  end

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

    org = if record.respond_to?(:project) && record.try(:project)&.organization
      record.project.organization
    else
      context_organization
    end

    return nil unless org

    @membership ||= user.memberships.find_by(organization: org)
  end
end
