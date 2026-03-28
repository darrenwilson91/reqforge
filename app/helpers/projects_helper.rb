module ProjectsHelper
  def project_status_badge_class(project)
    case project.status
    when "active"
      "rf-badge bg-emerald-50 text-emerald-700"
    when "archived"
      "rf-badge bg-slate-100 text-slate-600"
    when "template"
      "rf-badge bg-violet-50 text-violet-700"
    else
      "rf-badge bg-slate-100 text-slate-600"
    end
  end
end
