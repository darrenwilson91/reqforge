class OrganizationsController < ApplicationController
  skip_before_action :set_current_organization, only: [ :new, :create ]

  def new
    @organization = Organization.new
  end

  def create
    @organization = Organization.new(organization_params)

    if @organization.save
      @organization.memberships.create!(user: current_user, role: :admin)
      session[:current_organization_id] = @organization.id
      redirect_to root_path, notice: "Organization created successfully. Welcome to #{@organization.name}!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def organization_params
    params.require(:organization).permit(:name)
  end
end
