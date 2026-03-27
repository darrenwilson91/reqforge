class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :set_current_organization

  helper_method :current_organization, :current_membership

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def current_organization
    @current_organization
  end

  def current_membership
    return nil unless current_user && current_organization

    @current_membership ||= current_user.memberships.find_by(organization: current_organization)
  end

  def set_current_organization
    return unless current_user

    @current_organization = resolve_organization
    store_organization_in_session if @current_organization
  end

  def resolve_organization
    # 1. Try explicit switch via params
    if params[:organization_id].present?
      org = current_user.organizations.find_by(id: params[:organization_id])
      return org if org
    end

    # 2. Try session
    if session[:current_organization_id].present?
      org = current_user.organizations.find_by(id: session[:current_organization_id])
      return org if org
    end

    # 3. Fall back to user's first organization
    current_user.organizations.first
  end

  def store_organization_in_session
    session[:current_organization_id] = @current_organization.id
  end

  def require_organization!
    return if current_organization

    redirect_to new_organization_path, alert: "Please create or join an organization to continue."
  end

  # Multi-tenancy scoping: use in controllers to scope queries to the current organization.
  # Example: scoped_query(Project).find(params[:id])
  def scoped_query(model_class)
    model_class.for_organization(current_organization)
  end

  # Build a new record scoped to the current organization.
  # Example: build_scoped(Project, project_params)
  def build_scoped(model_class, attributes = {})
    model_class.new(attributes.merge(organization: current_organization))
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end
end
