# frozen_string_literal: true

class ReviewPolicy < ApplicationPolicy
  # All organization members can view reviews
  def index?
    membership.present?
  end

  def show?
    membership.present?
  end

  # Authors, PMs, and admins can create reviews
  def create?
    membership&.admin? || membership&.project_manager? || membership&.author?
  end

  # Only the review creator, PMs, and admins can update
  def update?
    return false unless membership
    return true if membership.admin? || membership.project_manager?

    record.respond_to?(:created_by) && record.created_by == user
  end

  # Only PMs and admins can delete reviews
  def destroy?
    membership&.admin? || membership&.project_manager?
  end

  # Transition status — same as update
  def transition_status?
    update?
  end

  # Add participants — creator, PMs, admins
  def manage_participants?
    update?
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
