module ChangeSetsHelper
  def change_set_status_badge_class(change_set)
    case change_set.status
    when "draft"      then "rf-badge bg-slate-100 text-slate-600"
    when "open"       then "rf-badge bg-blue-50 text-blue-700"
    when "in_review"  then "rf-badge bg-violet-50 text-violet-700"
    when "approved"   then "rf-badge bg-emerald-50 text-emerald-700"
    when "merged"     then "rf-badge bg-indigo-50 text-indigo-700"
    when "closed"     then "rf-badge bg-red-50 text-red-700"
    else "rf-badge bg-slate-100 text-slate-600"
    end
  end

  def change_set_transition_label(transition)
    case transition
    when "open"       then "Submit for Review"
    when "in_review"  then "Start Review"
    when "approved"   then "Approve"
    when "merged"     then "Merge"
    when "closed"     then "Close"
    when "draft"      then "Reopen as Draft"
    else transition.humanize
    end
  end

  def change_set_transition_button_class(transition)
    case transition
    when "open"       then "rf-btn-primary"
    when "in_review"  then "rf-btn-accent"
    when "approved"   then "rf-btn-primary bg-emerald-600 hover:bg-emerald-700"
    when "merged"     then "rf-btn-primary bg-indigo-600 hover:bg-indigo-700"
    when "closed"     then "rf-btn-danger"
    when "draft"      then "rf-btn-secondary"
    else "rf-btn-secondary"
    end
  end

  def change_type_badge_class(change_type)
    case change_type
    when "created"  then "rf-badge bg-emerald-50 text-emerald-700"
    when "modified" then "rf-badge bg-amber-50 text-amber-700"
    when "deleted"  then "rf-badge bg-red-50 text-red-700"
    else "rf-badge bg-slate-100 text-slate-600"
    end
  end

  def approval_status_badge_class(approval)
    case approval.status
    when "pending"           then "rf-badge bg-slate-100 text-slate-600"
    when "approved"          then "rf-badge bg-emerald-50 text-emerald-700"
    when "changes_requested" then "rf-badge bg-amber-50 text-amber-700"
    when "commented"         then "rf-badge bg-blue-50 text-blue-700"
    else "rf-badge bg-slate-100 text-slate-600"
    end
  end

  def approval_status_icon(approval)
    case approval.status
    when "approved"
      '<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-emerald-500" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" /></svg>'.html_safe
    when "changes_requested"
      '<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-amber-500" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" /></svg>'.html_safe
    when "commented"
      '<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-blue-500" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M18 13V5a2 2 0 00-2-2H4a2 2 0 00-2 2v8a2 2 0 002 2h3l3 3 3-3h3a2 2 0 002-2zM5 7a1 1 0 011-1h8a1 1 0 110 2H6a1 1 0 01-1-1zm1 3a1 1 0 100 2h3a1 1 0 100-2H6z" clip-rule="evenodd" /></svg>'.html_safe
    else
      '<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-slate-300" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM7 9a1 1 0 000 2h6a1 1 0 100-2H7z" clip-rule="evenodd" /></svg>'.html_safe
    end
  end

  def merge_eligibility_summary(change_set, rule)
    approvals_count = change_set.change_set_approvals.where(status: :approved).count
    min_needed = rule&.min_approvals || 1

    {
      approvals_met: approvals_count >= min_needed,
      approvals_count: approvals_count,
      approvals_needed: min_needed,
      changes_requested: change_set.any_changes_requested?,
      eligible: rule ? rule.merge_eligible?(change_set) : (approvals_count >= 1)
    }
  end
end
