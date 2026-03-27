class RequirementsController < ApplicationController
  before_action :set_project
  before_action :set_requirement, only: [ :show, :edit, :update, :destroy, :transition_status, :analyze_quality, :suggest_links, :analyze_impact ]

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
    @requirement.association(:ai_analysis_results).load_target
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
      enqueue_impact_analysis_if_needed
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

  def analyze_quality
    authorize @requirement, :update?
    AiAnalysisResult.mark_running!(@requirement, "quality_analysis")
    QualityAnalysisJob.perform_later(@requirement.id)

    respond_to do |format|
      format.turbo_stream do
        @requirement.reload
        @requirement.association(:ai_analysis_results).load_target
        render turbo_stream: turbo_stream.replace(
          "ai_analysis_panel",
          partial: "requirements/ai_panel",
          locals: { requirement: @requirement, project: @project }
        )
      end
      format.html do
        redirect_to project_requirement_path(@project, @requirement),
          notice: "Quality analysis started."
      end
    end
  end

  def suggest_links
    authorize @requirement, :update?
    AiAnalysisResult.mark_running!(@requirement, "link_suggestion")
    LinkSuggestionJob.perform_later(@requirement.id)

    respond_to do |format|
      format.turbo_stream do
        @requirement.reload
        @requirement.association(:ai_analysis_results).load_target
        render turbo_stream: turbo_stream.replace(
          "ai_analysis_panel",
          partial: "requirements/ai_panel",
          locals: { requirement: @requirement, project: @project }
        )
      end
      format.html do
        redirect_to project_requirement_path(@project, @requirement),
          notice: "Link suggestion analysis started."
      end
    end
  end

  def analyze_impact
    authorize @requirement, :update?
    AiAnalysisResult.mark_running!(@requirement, "impact_analysis")
    ImpactAnalysisJob.perform_later(@requirement.id)

    respond_to do |format|
      format.turbo_stream do
        @requirement.reload
        @requirement.association(:ai_analysis_results).load_target
        render turbo_stream: turbo_stream.replace(
          "ai_analysis_panel",
          partial: "requirements/ai_panel",
          locals: { requirement: @requirement, project: @project }
        )
      end
      format.html do
        redirect_to project_requirement_path(@project, @requirement),
          notice: "Impact analysis started."
      end
    end
  end

  def bulk_edit
    authorize @project, :update?
    @requirements = @project.requirements
      .includes(:section, section: :requirement_module)
      .order(:uid)
    @sections = build_section_options
  end

  def bulk_update
    authorize @project, :update?

    updates = params[:requirements]
    unless updates.is_a?(ActionController::Parameters) || updates.is_a?(Hash)
      return head :unprocessable_entity
    end

    updated_count = 0
    errors = []

    Requirement.transaction do
      updates.each do |id, attrs|
        req = @project.requirements.find_by(id: id)
        next unless req

        permitted = {}
        permitted[:title] = attrs[:title].strip if attrs[:title].present?
        permitted[:requirement_type] = attrs[:requirement_type] if attrs[:requirement_type].present?
        permitted[:status] = attrs[:status] if attrs[:status].present?
        permitted[:priority] = attrs[:priority] if attrs[:priority].present?
        permitted[:asil_level] = attrs[:asil_level] if attrs[:asil_level].present?
        permitted[:section_id] = attrs[:section_id] if attrs[:section_id].present?

        if req.update(permitted)
          updated_count += 1
        else
          errors << "#{req.uid}: #{req.errors.full_messages.join(', ')}"
        end
      end
    end

    if errors.any?
      redirect_to bulk_edit_project_requirements_path(@project), alert: "Some updates failed: #{errors.first(3).join('; ')}"
    else
      redirect_to bulk_edit_project_requirements_path(@project), notice: "#{updated_count} #{'requirement'.pluralize(updated_count)} updated."
    end
  end

  def bulk_delete
    authorize @project, :update?

    ids = params[:requirement_ids]
    unless ids.is_a?(Array)
      return redirect_to bulk_edit_project_requirements_path(@project), alert: "No requirements selected."
    end

    deleted = @project.requirements.where(id: ids).destroy_all
    redirect_to bulk_edit_project_requirements_path(@project), notice: "#{deleted.size} #{'requirement'.pluralize(deleted.size)} deleted."
  end

  def quick_entry
    authorize @project, :show?
    @modules = @project.requirement_modules.order(:position).includes(sections: :child_sections)
    @sections = build_section_options
    @existing_requirements = load_quick_entry_requirements
  end

  def quick_create
    authorize @project, :update?

    @requirement = @project.requirements.build(
      title: params[:title].to_s.strip,
      section_id: params[:section_id],
      created_by: current_user,
      requirement_type: params[:requirement_type].presence || "functional",
      priority: params[:priority].presence || "must_have",
      asil_level: params[:asil_level].presence || "qm"
    )

    if @requirement.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(
            "quick-entry-list",
            partial: "requirements/quick_entry_row",
            locals: { requirement: @requirement, project: @project }
          )
        end
        format.html { redirect_to quick_entry_project_requirements_path(@project, section_id: @requirement.section_id) }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to quick_entry_project_requirements_path(@project), alert: @requirement.errors.full_messages.join(", ") }
      end
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

  IMPACT_ANALYSIS_FIELDS = %w[title body requirement_type status priority asil_level].freeze

  def enqueue_impact_analysis_if_needed
    changed_fields = @requirement.previous_changes.slice(*IMPACT_ANALYSIS_FIELDS)
    return if changed_fields.empty?

    changes_hash = changed_fields.transform_values { |old_new| [ old_new[0].to_s, old_new[1].to_s ] }
    AiAnalysisResult.mark_running!(@requirement, "impact_analysis")
    ImpactAnalysisJob.perform_later(@requirement.id, changes_hash)
  end

  def load_tree_data
    @modules = @project.requirement_modules
      .order(:position)
      .includes(sections: [ :child_sections, :requirements ])
  end

  def load_form_data
    @modules = @project.requirement_modules.order(:position).includes(:sections)
    @sections = build_section_options
  end

  def build_section_options
    @project.requirement_modules
      .order(:position)
      .includes(sections: :child_sections)
      .flat_map do |mod|
        mod.sections.where(parent_section_id: nil).order(:position).map do |section|
          [ "#{mod.name} > #{section.name}", section.id ]
        end
      end
  end

  def load_quick_entry_requirements
    return [] unless params[:section_id].present?

    @project.requirements
      .where(section_id: params[:section_id])
      .includes(:section, section: :requirement_module)
      .order(:position)
  end
end
