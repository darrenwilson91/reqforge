module ReviewsHelper
  def review_status_badge_class(review)
    case review.status
    when "draft"       then "rf-badge bg-slate-100 text-slate-600"
    when "open"        then "rf-badge bg-blue-50 text-blue-700"
    when "in_progress" then "rf-badge bg-amber-50 text-amber-700"
    when "completed"   then "rf-badge bg-emerald-50 text-emerald-700"
    when "cancelled"   then "rf-badge bg-red-50 text-red-700"
    else "rf-badge bg-slate-100 text-slate-600"
    end
  end

  def review_item_status_badge_class(item)
    case item.status
    when "pending"       then "rf-badge bg-slate-100 text-slate-600"
    when "approved"      then "rf-badge bg-emerald-50 text-emerald-700"
    when "rejected"      then "rf-badge bg-red-50 text-red-700"
    when "needs_changes" then "rf-badge bg-amber-50 text-amber-700"
    else "rf-badge bg-slate-100 text-slate-600"
    end
  end

  def participant_role_badge_class(participant)
    case participant.role
    when "author"   then "rf-badge bg-blue-50 text-blue-700"
    when "reviewer"  then "rf-badge bg-violet-50 text-violet-700"
    when "approver"  then "rf-badge bg-emerald-50 text-emerald-700"
    when "observer"  then "rf-badge bg-slate-100 text-slate-600"
    else "rf-badge bg-slate-100 text-slate-600"
    end
  end

  def review_transition_label(transition)
    case transition
    when "open"        then "Open for Review"
    when "in_progress" then "Start Review"
    when "completed"   then "Complete Review"
    when "cancelled"   then "Cancel Review"
    when "draft"       then "Reopen as Draft"
    else transition.humanize
    end
  end

  def review_transition_button_class(transition)
    case transition
    when "open"        then "rf-btn-primary"
    when "in_progress" then "rf-btn-accent"
    when "completed"   then "rf-btn-primary bg-emerald-600 hover:bg-emerald-700"
    when "cancelled"   then "rf-btn-danger"
    when "draft"       then "rf-btn-secondary"
    else "rf-btn-secondary"
    end
  end

  def review_progress_bar_color(percentage)
    if percentage >= 100
      "bg-emerald-500"
    elsif percentage >= 50
      "bg-amber-500"
    else
      "bg-blue-500"
    end
  end
end
