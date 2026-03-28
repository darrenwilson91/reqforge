import { Controller } from "@hotwired/stimulus"

// Auto-dismisses flash messages after a configurable delay
export default class extends Controller {
  static values = { dismissAfter: { type: Number, default: 5000 } }

  connect() {
    if (this.dismissAfterValue > 0) {
      this.timeout = setTimeout(() => this.dismiss(), this.dismissAfterValue)
    }
  }

  dismiss() {
    this.element.style.transition = "opacity 300ms ease-out"
    this.element.style.opacity = "0"
    setTimeout(() => this.element.remove(), 300)
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }
}
