class RequirementsController < ApplicationController
  before_action :set_project
  before_action :set_requirement, only: [ :show, :edit, :update, :destroy, :transition_status ]

  def index
    authorize @project, :show?
    @requirements = @project.requirements
      .includes(:section, section: :requirement_module)
      .order(:uid)

    if params[:module_id].present?
      @requirements = @requirements
        .joins(section: :requirement_module)
        .where(requirement_modules: { id: params[:module_id] })
    end

    if params[:section_id].present?
      @requirements = @requirements.where(section_id: params[:section_id])
    end

    if params[:status].present?
      @requirements = @requirements.where(status: params[:status])
    end

    if params[:requirement_type].present?
      @requirements = @requirements.where(requirement_type: params[:requirement_type])
    end

    if params[:q].present?
      @requirements = @requirements.search_by_text(params[:q])
    end

    load_tree_data
  end

  def show
    authorize @requirement
    @active_requirement_id = @requirement.id
    load_tree_data
  end

  def new
    @requirement = @project.requirements.build(
      created_by: current_user,
      section_id: params[:section_id]
    )
    authorize @requirement
    load_form_data
  end

  def create
    @requirement = @project.requirements.build(requirement_params)
    @requirement.created_by = current_user
    authorize @requirement

    if @requirement.save
      redirect_to project_requirement_path(@project, @requirement), notice: "Requirement created successfully."
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @requirement
    load_form_data

    if turbo_frame_request?
      load_tree_data
      @active_requirement_id = @requirement.id
      render :show
    end
  end

  def update
    authorize @requirement
    if @requirement.update(requirement_params)
      redirect_to project_requirement_path(@project, @requirement), notice: "Requirement updated successfully."
    else
      load_form_data
      if turbo_frame_request?
        load_tree_data
        @active_requirement_id = @requirement.id
        render :show, status: :unprocessable_entity
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    authorize @requirement
    @requirement.destroy
    redirect_to project_requirements_path(@project), notice: "Requirement deleted successfully."
  end

  def transition_status
    authorize @requirement, :update?
    new_status = params[:status]

    if @requirement.transition_to(new_status)
      redirect_to project_requirement_path(@project, @requirement),
        notice: "Status changed to #{new_status.humanize}."
    else
      redirect_to project_requirement_path(@project, @requirement),
        alert: @requirement.errors.full_messages.join(", ")
    end
  end

  def search
    authorize @project, :show?
    query = params[:q].to_s.strip
    exclude_id = params[:exclude_id]

    @results = @project.requirements
      .includes(:section, section: :requirement_module)
      .order(:uid)

    if query.present?
      @results = @results.search_by_text(query)
    end

    @results = @results.where.not(id: exclude_id) if exclude_id.present?
    @results = @results.limit(20)

    render partial: "requirements/search_results", locals: { results: @results, project: @project }
  end

  def reorder
    authorize @project, :update?
    ordered_ids = params[:ordered_ids]

    unless ordered_ids.is_a?(Array) && ordered_ids.all? { |id| id.to_s.match?(/\A\d+\z/) }
      return head :unprocessable_entity
    end

    Requirement.transaction do
      ordered_ids.each_with_index do |id, index|
        @project.requirements.where(id: id).update_all(position: index + 1)
      end
    end

    head :ok
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:project_id])
  end

  def set_requirement
    @requirement = @project.requirements.find(params[:id])
  end

  def requirement_params
    permitted = params.require(:requirement).permit(
      :title, :body, :section_id, :requirement_type,
      :status, :priority, :asil_level
    )

    # Handle custom_attributes — they come as a nested hash from the form
    if params[:requirement][:custom_attributes].is_a?(ActionController::Parameters)
      permitted[:custom_attributes] = params[:requirement][:custom_attributes].permit!.to_h
    elsif params[:requirement][:custom_attributes].is_a?(String)
      permitted[:custom_attributes] = JSON.parse(params[:requirement][:custom_attributes]) rescue {}
    end

    permitted
  end

  def load_tree_data
    @modules = @project.requirement_modules
      .order(:position)
      .includes(sections: [ :child_sections, :requirements ])
  end

  def load_form_data
    @modules = @project.requirement_modules.order(:position).includes(:sections)
    @sections = @project.requirement_modules
      .order(:position)
      .includes(sections: :child_sections)
      .flat_map do |mod|
        mod.sections.where(parent_section_id: nil).order(:position).map do |section|
          [ "#{mod.name} > #{section.name}", section.id ]
        end
      end
  end
end
