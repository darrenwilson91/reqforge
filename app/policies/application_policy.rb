# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :record

  def initialize(context, record)
    @context = context
    @record = record
  end

  # Extract user from context (supports both UserContext and plain User)
  def user
    @context.respond_to?(:user) ? @context.user : @context
  end

  # Extract organization from context (nil when plain User is passed, e.g. in policy specs)
  def context_organization
    @context.respond_to?(:organization) ? @context.organization : nil
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(context, scope)
      @context = context
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :scope

    def user
      @context.respond_to?(:user) ? @context.user : @context
    end

    def context_organization
      @context.respond_to?(:organization) ? @context.organization : nil
    end
  end
end
