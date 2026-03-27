import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section", "chevron", "tab", "tabContent"]
  static values = { activeTab: { type: String, default: "quality" } }

  connect() {
    this.showTab(this.activeTabValue)
  }

  // Toggle individual collapsible sections within a tab
  toggle(event) {
    const button = event.currentTarget
    const section = button.closest("[data-ai-panel-target='section']")
    if (!section) return

    const content = section.querySelector("[data-content]")
    const chevron = button.querySelector("[data-chevron]")
    if (!content) return

    const isHidden = content.classList.contains("hidden")
    content.classList.toggle("hidden")
    if (chevron) {
      chevron.classList.toggle("rotate-90", isHidden)
    }
  }

  // Switch between Quality / Links / Impact tabs
  switchTab(event) {
    const tab = event.currentTarget.dataset.tab
    if (tab) {
      this.activeTabValue = tab
      this.showTab(tab)
    }
  }

  showTab(tabName) {
    // Update tab button styles
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tab === tabName
      tab.classList.toggle("border-brand-accent", isActive)
      tab.classList.toggle("text-brand-accent-dark", isActive)
      tab.classList.toggle("border-transparent", !isActive)
      tab.classList.toggle("text-slate-500", !isActive)
    })

    // Show/hide tab content
    this.tabContentTargets.forEach(content => {
      content.classList.toggle("hidden", content.dataset.tab !== tabName)
    })
  }

  expandAll() {
    this.sectionTargets.forEach(section => {
      const content = section.querySelector("[data-content]")
      const chevron = section.querySelector("[data-chevron]")
      if (content) content.classList.remove("hidden")
      if (chevron) chevron.classList.add("rotate-90")
    })
  }

  collapseAll() {
    this.sectionTargets.forEach(section => {
      const content = section.querySelector("[data-content]")
      const chevron = section.querySelector("[data-chevron]")
      if (content) content.classList.add("hidden")
      if (chevron) chevron.classList.remove("rotate-90")
    })
  }
}
