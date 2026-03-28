# frozen_string_literal: true

class ChangeSetPolicy < ApplicationPolicy
  # All organization members can view change sets
  def index?
    membership.present?
  end

  def show?
    membership.present?
  end

  # Authors, PMs, and admins can create change sets
  def create?
    membership&.admin? || membership&.project_manager? || membership&.author?
  end

  # Only the creator, PMs, and admins can update (while in draft/open)
  def update?
    return false unless membership
    return true if membership.admin? || membership.project_manager?

    record.respond_to?(:created_by) && record.created_by == user
  end

  # Only PMs and admins can delete change sets
  def destroy?
    membership&.admin? || membership&.project_manager?
  end

  # Transition status — creator, PMs, admins
  def transition_status?
    update?
  end

  # Approve/request changes — any member except the creator (can't approve own change set)
  def approve?
    return false unless membership
    return false if record.respond_to?(:created_by) && record.created_by == user

    membership.admin? || membership.project_manager? || membership.author? || membership.reviewer?
  end

  # Merge — only PMs and admins
  def merge?
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
