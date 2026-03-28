class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @results = []

    if @query.present?
      @results = org_requirements
        .search_by_text(@query)
        .includes(:project, section: :requirement_module)
        .limit(50)
    end
  end

  # GET /search/autocomplete?q=...
  # Returns HTML partial for the dropdown
  def autocomplete
    query = params[:q].to_s.strip
    results = []

    if query.present?
      results = org_requirements
        .search_by_text(query)
        .includes(:project, section: :requirement_module)
        .limit(8)
    end

    render partial: "search/autocomplete_results", locals: { results: results, query: query }
  end

  private

  def org_requirements
    Requirement.joins(section: { requirement_module: :project })
      .where(projects: { organization_id: current_organization.id })
  end
end
