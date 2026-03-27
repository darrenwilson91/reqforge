import { Controller } from "@hotwired/stimulus"

// Manages the compliance template selector during project creation.
// Shows template description and phase summary when a template is selected.
export default class extends Controller {
  static targets = ["details", "description", "phases", "attributes"]
  static values = { templates: Object }

  connect() {
    this.update()
  }

  update() {
    const select = this.element.querySelector("select")
    const templateId = select ? select.value : ""

    if (!templateId || !this.hasDetailsTarget) {
      if (this.hasDetailsTarget) this.detailsTarget.classList.add("hidden")
      return
    }

    const template = this.templatesValue[templateId]
    if (!template) {
      this.detailsTarget.classList.add("hidden")
      return
    }

    this.detailsTarget.classList.remove("hidden")

    if (this.hasDescriptionTarget) {
      this.descriptionTarget.textContent = template.description || ""
    }

    if (this.hasPhasesTarget) {
      this.renderPhases(template.phases || [])
    }

    if (this.hasAttributesTarget) {
      this.renderAttributes(template.attributes || [])
    }
  }

  renderPhases(phases) {
    const container = this.phasesTarget
    while (container.firstChild) container.removeChild(container.firstChild)

    phases.forEach((phase, index) => {
      const item = document.createElement("div")
      item.className = "flex items-center gap-2"

      const number = document.createElement("span")
      number.className = "flex-shrink-0 w-5 h-5 rounded-full bg-brand-accent/10 text-brand-accent text-xs font-bold flex items-center justify-center"
      number.textContent = String(index + 1)

      const name = document.createElement("span")
      name.className = "text-sm text-slate-700"
      name.textContent = phase.name

      item.appendChild(number)
      item.appendChild(name)
      container.appendChild(item)

      if (index < phases.length - 1) {
        const connector = document.createElement("div")
        connector.className = "ml-2.5 h-2 border-l border-slate-200"
        container.appendChild(connector)
      }
    })
  }

  renderAttributes(attributes) {
    const container = this.attributesTarget
    while (container.firstChild) container.removeChild(container.firstChild)

    attributes.forEach((attr) => {
      const badge = document.createElement("span")
      badge.className = "inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-600"

      const name = document.createElement("span")
      name.textContent = attr.name

      const type = document.createElement("span")
      type.className = "text-slate-400"
      type.textContent = `(${attr.type})`

      badge.appendChild(name)
      badge.appendChild(type)
      container.appendChild(badge)
    })
  }
}
