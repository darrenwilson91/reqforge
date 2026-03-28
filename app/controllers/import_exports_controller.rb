class ImportExportsController < ApplicationController
  before_action :set_project

  def show
    authorize @project, :show?
    @import_result = session.delete(:import_result)
  end

  # CSV Export
  def export_csv
    authorize @project, :show?

    exporter = CsvExporter.new(@project)
    csv_data = exporter.export

    send_data csv_data,
      filename: "#{@project.prefix}_requirements_#{Date.current.iso8601}.csv",
      type: "text/csv; charset=utf-8",
      disposition: "attachment"
  end

  # ReqIF Export
  def export_reqif
    authorize @project, :show?

    exporter = ReqifExporter.new(@project)
    xml_data = exporter.export

    send_data xml_data,
      filename: "#{@project.prefix}_requirements_#{Date.current.iso8601}.reqif",
      type: "application/xml; charset=utf-8",
      disposition: "attachment"
  end

  # CSV Import
  def import_csv
    authorize @project, :update?

    unless params[:file].present?
      redirect_to project_import_export_path(@project), alert: "Please select a CSV file to import."
      return
    end

    file = params[:file]
    unless file.content_type.in?(%w[text/csv application/vnd.ms-excel text/plain])
      redirect_to project_import_export_path(@project), alert: "Invalid file type. Please upload a CSV file."
      return
    end

    content = file.read.force_encoding("UTF-8")
    importer = CsvImporter.new(@project, current_user)
    result = importer.import(content)

    session[:import_result] = result.merge(format: "CSV")
    redirect_to project_import_export_path(@project),
      notice: result[:success] ? "Successfully imported #{result[:imported]} requirements from CSV." : nil,
      alert: result[:success] ? nil : "Import failed. #{result[:errors].map { |e| "Row #{e[:row]}: #{e[:message]}" }.first(5).join('; ')}."
  rescue CsvImporter::Error => e
    redirect_to project_import_export_path(@project), alert: "CSV import error: #{e.message}"
  end

  # ReqIF Import
  def import_reqif
    authorize @project, :update?

    unless params[:file].present?
      redirect_to project_import_export_path(@project), alert: "Please select a ReqIF file to import."
      return
    end

    file = params[:file]
    unless file.original_filename&.end_with?(".reqif", ".xml")
      redirect_to project_import_export_path(@project), alert: "Invalid file type. Please upload a ReqIF (.reqif or .xml) file."
      return
    end

    content = file.read.force_encoding("UTF-8")
    importer = ReqifImporter.new(@project, current_user)
    result = importer.import(content)

    session[:import_result] = result.merge(format: "ReqIF")
    link_warning_text = result[:link_warnings]&.any? ? " (#{result[:link_warnings].size} link warning#{'s' if result[:link_warnings].size != 1})" : ""
    redirect_to project_import_export_path(@project),
      notice: result[:success] ? "Successfully imported #{result[:imported_requirements]} requirements and #{result[:imported_links]} links from ReqIF.#{link_warning_text}" : nil,
      alert: result[:success] ? nil : "Import failed. #{result[:errors].map { |e| e[:message] || e.to_s }.first(5).join('; ')}."
  rescue ReqifImporter::Error => e
    redirect_to project_import_export_path(@project), alert: "ReqIF import error: #{e.message}"
  end

  private

  def set_project
    @project = scoped_query(Project).find(params[:project_id])
  end
end
