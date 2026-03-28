class TestCasesController < ApplicationController
  before_action :set_project
  before_action :set_test_case, only: [ :show, :edit, :update, :destroy ]

  def index
    @test_cases = @project.test_cases
      .includes(:requirement, :created_by)
      .order(:uid)

    if params[:test_type].present?
      @test_cases = @test_cases.where(test_type: params[:test_type])
    end

    if params[:status].present?
      @test_cases = @test_cases.where(status: params[:status])
    end

    if params[:requirement_id].present?
      @test_cases = @test_cases.where(requirement_id: params[:requirement_id])
    end

    if params[:q].present?
      @test_cases = @test_cases.where(
        "test_cases.title ILIKE :q OR test_cases.uid ILIKE :q",
        q: "%#{params[:q]}%"
      )
    end
  end

  def show
  end

  def new
    @test_case = @project.test_cases.build(
      created_by: current_user,
      requirement_id: params[:requirement_id]
    )
    load_form_data
  end

  def create
    @test_case = @project.test_cases.build(test_case_params)
    @test_case.created_by = current_user

    if @test_case.save
      redirect_to project_test_case_path(@project, @test_case), notice: "Test case created successfully."
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_data
  end

  def update
    if @test_case.update(test_case_params)
      redirect_to project_test_case_path(@project, @test_case), notice: "Test case updated successfully."
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @test_case.destroy
    redirect_to project_test_cases_path(@project), notice: "Test case deleted successfully."
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:project_id])
  end

  def set_test_case
    @test_case = @project.test_cases.find(params[:id])
  end

  def test_case_params
    params.require(:test_case).permit(
      :title, :description, :preconditions, :steps,
      :expected_result, :test_type, :status, :priority,
      :requirement_id
    )
  end

  def load_form_data
    @requirements = @project.requirements.order(:uid)
  end
end
