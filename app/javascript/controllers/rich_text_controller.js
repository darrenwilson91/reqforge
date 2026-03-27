import { Controller } from "@hotwired/stimulus"
import "trix"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    // Configure Trix toolbar — remove file attachment button (not needed for requirements)
    this.element.addEventListener("trix-file-accept", (e) => {
      e.preventDefault()
    })
  }

  disconnect() {
    // Clean up any event listeners
  }
}
