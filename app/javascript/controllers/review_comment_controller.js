import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["replyForm", "replyBody", "commentBody"]

  toggleReply(event) {
    event.preventDefault()
    const form = this.replyFormTarget
    if (form.classList.contains("hidden")) {
      form.classList.remove("hidden")
      this.replyBodyTarget.focus()
    } else {
      form.classList.add("hidden")
      this.replyBodyTarget.value = ""
    }
  }

  cancelReply(event) {
    event.preventDefault()
    this.replyFormTarget.classList.add("hidden")
    this.replyBodyTarget.value = ""
  }

  validateSubmit(event) {
    const body = this.commentBodyTarget.value.trim()
    if (!body) {
      event.preventDefault()
      this.commentBodyTarget.classList.add("ring-2", "ring-red-300")
      this.commentBodyTarget.focus()
      setTimeout(() => {
        this.commentBodyTarget.classList.remove("ring-2", "ring-red-300")
      }, 2000)
    }
  }
}
