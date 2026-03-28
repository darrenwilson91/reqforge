import { Controller } from "@hotwired/stimulus"

// Manages sidebar collapse/expand behavior on desktop and mobile overlay
export default class extends Controller {
  static targets = ["nav", "overlay"]

  connect() {
    this.handleResize = this.handleResize.bind(this)
    window.addEventListener("resize", this.handleResize)
  }

  disconnect() {
    window.removeEventListener("resize", this.handleResize)
  }

  open() {
    this.navTarget.classList.remove("-translate-x-full")
    this.overlayTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden", "lg:overflow-auto")
  }

  close() {
    this.navTarget.classList.add("-translate-x-full")
    this.overlayTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden", "lg:overflow-auto")
  }

  handleResize() {
    if (window.innerWidth >= 1024) {
      this.navTarget.classList.remove("-translate-x-full")
      this.overlayTarget.classList.add("hidden")
      document.body.classList.remove("overflow-hidden", "lg:overflow-auto")
    } else {
      // On mobile, sidebar should be hidden unless explicitly opened
      if (!this.overlayTarget.classList.contains("hidden")) return
      this.navTarget.classList.add("-translate-x-full")
    }
  }
}
