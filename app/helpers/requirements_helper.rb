module RequirementsHelper
  def requirement_status_badge_class(requirement)
    case requirement.status
    when "draft"       then "rf-badge-draft"
    when "in_review"   then "rf-badge-in-review"
    when "approved"    then "rf-badge-approved"
    when "implemented" then "rf-badge-implemented"
    when "verified"    then "rf-badge-verified"
    when "obsolete"    then "rf-badge-obsolete"
    else "rf-badge-draft"
    end
  end

  def requirement_type_badge_class(requirement)
    case requirement.requirement_type
    when "functional"        then "rf-badge bg-blue-50 text-blue-700"
    when "non_functional"    then "rf-badge bg-purple-50 text-purple-700"
    when "safety"            then "rf-badge bg-red-50 text-red-700"
    when "interface"         then "rf-badge bg-teal-50 text-teal-700"
    when "design_constraint" then "rf-badge bg-orange-50 text-orange-700"
    else "rf-badge bg-slate-100 text-slate-600"
    end
  end

  def requirement_priority_badge_class(requirement)
    case requirement.priority
    when "must_have"   then "rf-badge bg-red-50 text-red-700"
    when "should_have" then "rf-badge bg-amber-50 text-amber-700"
    when "could_have"  then "rf-badge bg-blue-50 text-blue-700"
    when "wont_have"   then "rf-badge bg-slate-100 text-slate-600"
    else "rf-badge bg-slate-100 text-slate-600"
    end
  end

  def asil_badge_class(requirement)
    case requirement.asil_level
    when "qm"     then "rf-asil-qm"
    when "asil_a" then "rf-asil-a"
    when "asil_b" then "rf-asil-b"
    when "asil_c" then "rf-asil-c"
    when "asil_d" then "rf-asil-d"
    else "rf-asil-qm"
    end
  end

  def link_type_badge_class(link_type)
    case link_type.to_s
    when "derives_from"   then "bg-blue-50 text-blue-700"
    when "satisfies"      then "bg-emerald-50 text-emerald-700"
    when "verifies"       then "bg-violet-50 text-violet-700"
    when "conflicts_with" then "bg-red-50 text-red-700"
    when "refines"        then "bg-amber-50 text-amber-700"
    when "implements"     then "bg-teal-50 text-teal-700"
    when "parent_child"   then "bg-slate-100 text-slate-600"
    else "bg-slate-100 text-slate-600"
    end
  end

  def link_type_dot_class(link_type)
    case link_type.to_s
    when "derives_from"   then "bg-blue-500"
    when "satisfies"      then "bg-emerald-500"
    when "verifies"       then "bg-violet-500"
    when "conflicts_with" then "bg-red-500"
    when "refines"        then "bg-amber-500"
    when "implements"     then "bg-teal-500"
    when "parent_child"   then "bg-slate-400"
    else "bg-slate-400"
    end
  end

  # AI Panel helpers — score-based color coding

  def ai_score_badge_class(score)
    if score >= 80
      "bg-emerald-100 text-emerald-800"
    elsif score >= 60
      "bg-amber-100 text-amber-800"
    else
      "bg-red-100 text-red-800"
    end
  end

  def ai_score_ring_class(score)
    if score >= 80
      "stroke-emerald-500"
    elsif score >= 60
      "stroke-amber-500"
    else
      "stroke-red-500"
    end
  end

  def ai_score_text_class(score)
    if score >= 80
      "text-emerald-600"
    elsif score >= 60
      "text-amber-600"
    else
      "text-red-600"
    end
  end

  def ai_score_bar_class(score)
    if score >= 80
      "bg-emerald-500"
    elsif score >= 60
      "bg-amber-500"
    else
      "bg-red-500"
    end
  end

  def impact_risk_level_class(risk_level)
    case risk_level.to_s
    when "critical"    then "bg-red-50 text-red-800 border border-red-200"
    when "significant" then "bg-orange-50 text-orange-800 border border-orange-200"
    when "moderate"    then "bg-amber-50 text-amber-800 border border-amber-200"
    when "minimal"     then "bg-emerald-50 text-emerald-800 border border-emerald-200"
    else "bg-slate-50 text-slate-800 border border-slate-200"
    end
  end

  def impact_severity_border_class(severity)
    case severity.to_s
    when "high"   then "border-red-200 bg-red-50/30"
    when "medium" then "border-amber-200 bg-amber-50/30"
    when "low"    then "border-slate-150 bg-slate-50/30"
    else "border-slate-100"
    end
  end

  def impact_severity_dot_class(severity)
    case severity.to_s
    when "high"   then "bg-red-500"
    when "medium" then "bg-amber-500"
    when "low"    then "bg-slate-400"
    else "bg-slate-300"
    end
  end

  def impact_severity_badge_class(severity)
    case severity.to_s
    when "high"   then "bg-red-100 text-red-700"
    when "medium" then "bg-amber-100 text-amber-700"
    when "low"    then "bg-slate-100 text-slate-600"
    else "bg-slate-100 text-slate-600"
    end
  end
end
