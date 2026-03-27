import { Controller } from "@hotwired/stimulus"

// Keyboard shortcuts for requirement management.
// Attach to the body element via the application layout.
//
// Shortcuts:
//   n — New requirement (navigates to new requirement form)
//   e — Edit current requirement (triggers inline edit)
//   s — Save (submits the active form within the requirement_detail frame)
//   Esc — Cancel editing (clicks the cancel/discard link)
//   ? — Toggle keyboard shortcuts help overlay
export default class extends Controller {
  static targets = ["overlay"]

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    // Never intercept when a modifier key is held
    if (event.metaKey || event.ctrlKey || event.altKey) return

    // Close overlay on Escape regardless of focus
    if (event.key === "Escape") {
      if (this.hasOverlayTarget && !this.overlayTarget.classList.contains("hidden")) {
        this.hideOverlay()
        event.preventDefault()
        return
      }
      this.cancel(event)
      return
    }

    // Don't intercept when user is typing in an input field
    if (this.isTyping(event.target)) return

    switch (event.key) {
      case "n":
        this.newRequirement(event)
        break
      case "e":
        this.editRequirement(event)
        break
      case "s":
        this.saveRequirement(event)
        break
      case "?":
        this.toggleOverlay(event)
        break
    }
  }

  isTyping(element) {
    const tagName = element.tagName.toLowerCase()
    if (tagName === "input" || tagName === "textarea" || tagName === "select") return true
    if (tagName === "trix-editor") return true
    if (element.isContentEditable) return true
    return false
  }

  newRequirement(event) {
    const link = document.querySelector("[data-keyboard-shortcut='new-requirement']")
    if (link) {
      event.preventDefault()
      link.click()
    }
  }

  editRequirement(event) {
    const link = document.querySelector("[data-keyboard-shortcut='edit-requirement']")
    if (link) {
      event.preventDefault()
      link.click()
    }
  }

  saveRequirement(event) {
    // Find the form inside the requirement_detail turbo frame
    const frame = document.getElementById("requirement_detail")
    if (!frame) return

    const form = frame.querySelector("form")
    if (form) {
      event.preventDefault()
      form.requestSubmit()
    }
  }

  cancel(event) {
    // Find the cancel/discard link inside the requirement_detail turbo frame
    const frame = document.getElementById("requirement_detail")
    if (!frame) return

    const cancelLink = frame.querySelector("[data-keyboard-shortcut='cancel-edit']")
    if (cancelLink) {
      event.preventDefault()
      cancelLink.click()
    }
  }

  toggleOverlay(event) {
    if (!this.hasOverlayTarget) return
    event.preventDefault()

    if (this.overlayTarget.classList.contains("hidden")) {
      this.showOverlay()
    } else {
      this.hideOverlay()
    }
  }

  showOverlay() {
    if (!this.hasOverlayTarget) return
    this.overlayTarget.classList.remove("hidden")
    this.overlayTarget.classList.add("flex")
  }

  hideOverlay() {
    if (!this.hasOverlayTarget) return
    this.overlayTarget.classList.add("hidden")
    this.overlayTarget.classList.remove("flex")
  }
}
