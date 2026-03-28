class ProjectsController < ApplicationController
  before_action :set_project, only: [ :show, :edit, :update, :destroy ]

  def index
    @projects = scoped_query(Project).order(updated_at: :desc)
    authorize Project
  end

  def show
    authorize @project
    @modules = @project.requirement_modules.order(:position).includes(sections: :requirements)
    load_project_dashboard_metrics
  end

  def new
    @project = build_scoped(Project)
    authorize @project
  end

  def create
    @project = build_scoped(Project, project_params)
    authorize @project

    if @project.save
      apply_compliance_template(@project)
      redirect_to project_path(@project), notice: "Project created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @project
  end

  def update
    authorize @project
    if @project.update(project_params)
      redirect_to project_path(@project), notice: "Project updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @project
    @project.destroy
    redirect_to projects_path, notice: "Project deleted successfully."
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:id])
  end

  def load_project_dashboard_metrics
    reqs = @project.requirements

    # Requirements breakdown by status
    @req_status_counts = reqs.group(:status).count
    @req_total = reqs.count

    # Traceability health
    req_ids = reqs.pluck(:id)
    @reqs_with_forward_links = TraceabilityLink.where(source_requirement_id: req_ids).distinct.count(:source_requirement_id)
    @reqs_with_backward_links = TraceabilityLink.where(target_requirement_id: req_ids).distinct.count(:target_requirement_id)
    @reqs_with_test_cases = TestCase.where(requirement_id: req_ids).distinct.count(:requirement_id)
    @forward_pct = @req_total > 0 ? (@reqs_with_forward_links.to_f / @req_total * 100).round : 0
    @backward_pct = @req_total > 0 ? (@reqs_with_backward_links.to_f / @req_total * 100).round : 0
    @test_coverage_pct = @req_total > 0 ? (@reqs_with_test_cases.to_f / @req_total * 100).round : 0
    @traceability_link_count = TraceabilityLink.where(source_requirement_id: req_ids).or(TraceabilityLink.where(target_requirement_id: req_ids)).count

    # Change set velocity
    change_sets = @project.change_sets
    @cs_open = change_sets.where(status: [ :draft, :open, :in_review, :approved ]).count
    @cs_merged = change_sets.where(status: :merged).count
    @cs_closed = change_sets.where(status: :closed).count

    # Review bottlenecks: change sets in_review for > 3 days
    @stale_change_sets = change_sets.where(status: :in_review)
                                    .where("change_sets.updated_at < ?", 3.days.ago)
                                    .includes(:created_by)
                                    .order(updated_at: :asc)
                                    .limit(5)

    # Outstanding approvals by reviewer
    @outstanding_approvals = ChangeSetApproval.joins(:change_set)
                                              .where(change_sets: { project_id: @project.id, status: :in_review })
                                              .where(change_set_approvals: { status: :pending })
                                              .includes(:user)
                                              .group_by(&:user)

    # ASIL coverage
    @asil_counts = reqs.group(:asil_level).count
    @asil_approved = reqs.where(status: [ :approved, :implemented, :verified ]).group(:asil_level).count

    # Test case summary
    @test_case_total = @project.test_cases.count
    @test_case_passed = @project.test_cases.where(status: :passed).count
    @test_case_failed = @project.test_cases.where(status: :failed).count
  end

  def apply_compliance_template(project)
    template_id = params[:compliance_template_id]
    return if template_id.blank?

    template = ComplianceTemplate.active.find_by(id: template_id)
    return unless template

    template.apply_to_project!(project)
  end

  def project_params
    permitted = params.require(:project).permit(:name, :description, :prefix, :status, :attribute_schema)
    if permitted[:attribute_schema].is_a?(String)
      permitted[:attribute_schema] = JSON.parse(permitted[:attribute_schema]) rescue []
    end
    permitted
  end
end
