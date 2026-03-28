import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "count"]

  connect() {
    this.updateCount()
  }

  selectAll() {
    this.checkboxTargets.forEach(cb => cb.checked = true)
    this.updateCount()
  }

  deselectAll() {
    this.checkboxTargets.forEach(cb => cb.checked = false)
    this.updateCount()
  }

  updateCount() {
    if (!this.hasCountTarget) return
    const selected = this.checkboxTargets.filter(cb => cb.checked).length
    this.countTarget.textContent = `${selected} requirement${selected === 1 ? '' : 's'} selected`
  }

  // Called on checkbox change via data-action
  toggle() {
    this.updateCount()
  }
}
