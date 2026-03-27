module ApplicationHelper
  def breadcrumbs(*items)
    content_tag(:nav, class: "flex items-center gap-2 text-sm text-slate-500", aria: { label: "Breadcrumb" }) do
      parts = []
      items.each_with_index do |item, index|
        parts << breadcrumb_chevron if index > 0

        if index == items.length - 1
          label = item.is_a?(Array) ? item[0] : item
          parts << content_tag(:span, label, class: "text-slate-900 font-medium")
        elsif item.is_a?(Array)
          parts << link_to(item[0], item[1], class: "hover:text-brand-accent-dark transition-colors")
        else
          parts << content_tag(:span, item, class: "font-medium text-slate-600")
        end
      end
      safe_join(parts)
    end
  end

  private

  def breadcrumb_chevron
    '<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-slate-300" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd" /></svg>'.html_safe
  end
end
