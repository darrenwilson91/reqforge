import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["replyForm", "replyButton"]

  toggleReply(event) {
    const commentId = event.currentTarget.dataset.commentId
    const form = this.element.querySelector(`[data-reply-form-id="${commentId}"]`)
    const button = event.currentTarget

    if (form) {
      const isHidden = form.classList.contains("hidden")
      form.classList.toggle("hidden")
      button.textContent = isHidden ? "Cancel" : "Reply"

      if (isHidden) {
        const textarea = form.querySelector("textarea")
        if (textarea) textarea.focus()
      }
    }
  }

  cancelReply(event) {
    const commentId = event.currentTarget.dataset.commentId
    const form = this.element.querySelector(`[data-reply-form-id="${commentId}"]`)
    const replyBtn = this.element.querySelector(`[data-comment-id="${commentId}"][data-action*="toggleReply"]`)

    if (form) {
      form.classList.add("hidden")
      const textarea = form.querySelector("textarea")
      if (textarea) textarea.value = ""
    }
    if (replyBtn) {
      replyBtn.textContent = "Reply"
    }
  }

  validateSubmit(event) {
    const form = event.currentTarget.closest("form")
    const textarea = form?.querySelector("textarea")
    if (textarea && textarea.value.trim() === "") {
      event.preventDefault()
      textarea.classList.add("ring-2", "ring-red-300")
      setTimeout(() => textarea.classList.remove("ring-2", "ring-red-300"), 1500)
    }
  }
}
