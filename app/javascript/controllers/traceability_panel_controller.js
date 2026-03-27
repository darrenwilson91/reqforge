import { Controller } from "@hotwired/stimulus"

// Manages expand/collapse behavior for traceability link type sections
export default class extends Controller {
  static targets = ["section", "chevron", "content"]

  toggle(event) {
    const section = event.currentTarget.closest("[data-traceability-panel-target='section']")
    if (!section) return

    const chevron = section.querySelector("[data-traceability-panel-target='chevron']")
    const content = section.querySelector("[data-traceability-panel-target='content']")
    if (!content) return

    const isHidden = content.classList.contains("hidden")
    content.classList.toggle("hidden", !isHidden)
    if (chevron) {
      chevron.classList.toggle("rotate-90", isHidden)
    }
  }

  expandAll() {
    this.sectionTargets.forEach(section => {
      const chevron = section.querySelector("[data-traceability-panel-target='chevron']")
      const content = section.querySelector("[data-traceability-panel-target='content']")
      if (content) {
        content.classList.remove("hidden")
      }
      if (chevron) {
        chevron.classList.add("rotate-90")
      }
    })
  }

  collapseAll() {
    this.sectionTargets.forEach(section => {
      const chevron = section.querySelector("[data-traceability-panel-target='chevron']")
      const content = section.querySelector("[data-traceability-panel-target='content']")
      if (content) {
        content.classList.add("hidden")
      }
      if (chevron) {
        chevron.classList.remove("rotate-90")
      }
    })
  }

  // On connect, expand all sections by default for visibility
  connect() {
    this.expandAll()
  }
}
