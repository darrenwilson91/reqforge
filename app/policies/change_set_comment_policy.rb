# frozen_string_literal: true

class ChangeSetCommentPolicy < ApplicationPolicy
  # All organization members can view comments
  def index?
    membership.present?
  end

  def show?
    membership.present?
  end

  # All org members except viewers can create comments
  def create?
    return false unless membership

    membership.admin? || membership.project_manager? || membership.author? || membership.reviewer?
  end

  # Resolve/unresolve — any member who can create comments
  def resolve?
    create?
  end

  def unresolve?
    create?
  end

  private

  def membership
    return nil unless user

    org = if record.respond_to?(:change_set) && record.try(:change_set)&.project&.organization
      record.change_set.project.organization
    else
      context_organization
    end

    return nil unless org

    @membership ||= user.memberships.find_by(organization: org)
  end
end
