import { Controller } from "@hotwired/stimulus"

// Manages dropdown menu visibility with click-outside dismissal
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.clickOutsideHandler = this.clickOutside.bind(this)
  }

  toggle() {
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    document.addEventListener("click", this.clickOutsideHandler, { once: true, capture: true })
  }

  close() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.clickOutsideHandler, { capture: true })
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    } else {
      // Re-attach if click was inside (toggle will handle it)
      document.addEventListener("click", this.clickOutsideHandler, { once: true, capture: true })
    }
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutsideHandler, { capture: true })
  }
}
