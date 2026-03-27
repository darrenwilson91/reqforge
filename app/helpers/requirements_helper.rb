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
end
