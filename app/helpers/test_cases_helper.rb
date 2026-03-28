module TestCasesHelper
  def test_type_badge_class(test_case)
    case test_case.test_type
    when "unit"        then "rf-badge bg-blue-50 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300"
    when "integration" then "rf-badge bg-violet-50 text-violet-700 dark:bg-violet-900/30 dark:text-violet-300"
    when "system"      then "rf-badge bg-teal-50 text-teal-700 dark:bg-teal-900/30 dark:text-teal-300"
    when "acceptance"  then "rf-badge bg-emerald-50 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300"
    when "safety"      then "rf-badge bg-red-50 text-red-700 dark:bg-red-900/30 dark:text-red-300"
    else "rf-badge bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
    end
  end

  def test_status_badge_class(test_case)
    case test_case.status
    when "draft"   then "rf-badge-draft"
    when "ready"   then "rf-badge bg-blue-50 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300"
    when "passed"  then "rf-badge bg-emerald-50 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300"
    when "failed"  then "rf-badge bg-red-50 text-red-700 dark:bg-red-900/30 dark:text-red-300"
    when "blocked" then "rf-badge bg-amber-50 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300"
    when "not_run" then "rf-badge bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
    else "rf-badge bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
    end
  end

  def test_priority_badge_class(test_case)
    case test_case.priority
    when "must_have"   then "rf-badge bg-red-50 text-red-700 dark:bg-red-900/30 dark:text-red-300"
    when "should_have" then "rf-badge bg-amber-50 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300"
    when "could_have"  then "rf-badge bg-blue-50 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300"
    when "wont_have"   then "rf-badge bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
    else "rf-badge bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
    end
  end

  def test_status_icon(test_case)
    case test_case.status
    when "passed"
      '<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-emerald-500" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" /></svg>'.html_safe
    when "failed"
      '<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-red-500" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" /></svg>'.html_safe
    when "blocked"
      '<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-amber-500" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M13.477 14.89A6 6 0 015.11 6.524l8.367 8.368zm1.414-1.414L6.524 5.11a6 6 0 018.367 8.367zM18 10a8 8 0 11-16 0 8 8 0 0116 0z" clip-rule="evenodd" /></svg>'.html_safe
    when "ready"
      '<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-blue-500" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd" /></svg>'.html_safe
    else
      '<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-slate-400" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z" clip-rule="evenodd" /></svg>'.html_safe
    end
  end
end
