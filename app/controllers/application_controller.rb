UserContext = Struct.new(:user, :organization, keyword_init: true)

class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :set_current_organization
  before_action :require_organization_setup!
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :current_organization, :current_membership, :active_change_set

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Override Pundit's user context to include the current organization
  # so policies can resolve membership for class-level authorization (index?, create?)
  def pundit_user
    UserContext.new(user: current_user, organization: current_organization)
  end

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

  def require_organization_setup!
    return unless current_user
    return if current_organization
    return if devise_controller?
    return if self.is_a?(OrganizationsController)

    redirect_to new_organization_path, alert: "Please create or join an organization to continue."
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

  # Returns the currently active change set for the current project context.
  # Stored in session[:active_change_set_id], scoped to the current @project.
  # Returns nil if no active change set, no project context, or the change set
  # is in a terminal state (merged/closed).
  def active_change_set
    return @_active_change_set if defined?(@_active_change_set)

    cs_id = session[:active_change_set_id]
    return @_active_change_set = nil unless cs_id
    return @_active_change_set = nil unless defined?(@project) && @project

    @_active_change_set = @project.change_sets
      .where(id: cs_id, status: [ :draft, :open, :in_review, :approved ])
      .first
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name ])
  end

  def user_not_authorized
    respond_to do |format|
      format.json { head :forbidden }
      format.html do
        flash[:alert] = "You are not authorized to perform this action."
        redirect_back(fallback_location: root_path)
      end
    end
  end
end
