import { Controller } from "@hotwired/stimulus"

// Controls expand/collapse of individual version entries in the history panel
export default class extends Controller {
  static targets = ["entry", "content", "chevron"]

  toggle(event) {
    const index = event.params.index
    const content = this.contentTargets[index]
    const chevron = this.chevronTargets[index]

    if (!content || !chevron) return

    const isHidden = content.classList.contains("hidden")

    if (isHidden) {
      content.classList.remove("hidden")
      chevron.classList.add("rotate-90")
    } else {
      content.classList.add("hidden")
      chevron.classList.remove("rotate-90")
    }
  }

  expandAll() {
    this.contentTargets.forEach((content, i) => {
      content.classList.remove("hidden")
      if (this.chevronTargets[i]) {
        this.chevronTargets[i].classList.add("rotate-90")
      }
    })
  }

  collapseAll() {
    this.contentTargets.forEach((content, i) => {
      content.classList.add("hidden")
      if (this.chevronTargets[i]) {
        this.chevronTargets[i].classList.remove("rotate-90")
      }
    })
  }
}
