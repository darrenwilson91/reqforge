import { Controller } from "@hotwired/stimulus"

// Manages skeleton-to-content transitions for lazy-loaded Turbo Frames.
//
// Usage:
//   <div data-controller="loading">
//     <div data-loading-target="skeleton">...skeleton markup...</div>
//     <div data-loading-target="content" class="hidden">...real content...</div>
//   </div>
//
// Or with a Turbo Frame:
//   <turbo-frame id="..." data-controller="loading" data-loading-target="frame">
//     <div data-loading-target="skeleton">...skeleton...</div>
//   </turbo-frame>
//
// The skeleton is shown initially. When content target connects or the
// Turbo Frame finishes loading, the skeleton fades out and content fades in.
export default class extends Controller {
  static targets = ["skeleton", "content"]

  connect() {
    // Listen for Turbo Frame load completion on the element itself
    this.element.addEventListener("turbo:frame-load", this.reveal.bind(this))
  }

  contentTargetConnected() {
    this.reveal()
  }

  reveal() {
    if (this.hasSkeletonTarget) {
      this.skeletonTarget.style.transition = "opacity 150ms ease-out"
      this.skeletonTarget.style.opacity = "0"
      setTimeout(() => {
        this.skeletonTarget.classList.add("hidden")
        if (this.hasContentTarget) {
          this.contentTarget.classList.remove("hidden")
          this.contentTarget.style.opacity = "0"
          this.contentTarget.style.transition = "opacity 200ms ease-in"
          // Force a reflow before setting opacity to 1
          this.contentTarget.offsetHeight
          this.contentTarget.style.opacity = "1"
        }
      }, 150)
    } else if (this.hasContentTarget) {
      this.contentTarget.classList.remove("hidden")
    }
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-load", this.reveal.bind(this))
  }
}
