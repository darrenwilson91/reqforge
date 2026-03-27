import { Controller } from "@hotwired/stimulus"

// Manages sidebar collapse/expand behavior
export default class extends Controller {
  static targets = ["content"]

  toggle() {
    this.element.classList.toggle("w-64")
    this.element.classList.toggle("w-16")
  }
}
