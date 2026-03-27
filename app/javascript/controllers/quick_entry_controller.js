import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["titleInput", "sectionSelect", "sectionSwitcher", "nextUid", "sessionCount", "totalCount", "inputArea", "actionBar"]
  static values = { url: String, section: String }

  connect() {
    this._sessionCount = 0
    this._saving = false
    this.autoResizeInput()
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.createRequirement()
    }
    // Shift+Enter: default textarea behavior (newline) — no action needed
  }

  async createRequirement() {
    if (this._saving) return

    const input = this.titleInputTarget
    const title = input.value.trim()
    if (!title) return

    const sectionId = this.sectionSelectTarget.value
    if (!sectionId) return

    this._saving = true
    input.disabled = true

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": token,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: new URLSearchParams({
          title: title,
          section_id: sectionId
        })
      })

      if (response.ok) {
        // Process turbo stream response to append the new row
        const html = await response.text()
        Turbo.renderStreamMessage(html)

        // Clear input and refocus
        input.value = ""
        this.autoResizeInput()

        // Update counters
        this._sessionCount++
        this.updateCounters()
      } else {
        // Flash the input to indicate error
        input.classList.add("ring-2", "ring-red-400")
        setTimeout(() => input.classList.remove("ring-2", "ring-red-400"), 1500)
      }
    } catch (error) {
      input.classList.add("ring-2", "ring-red-400")
      setTimeout(() => input.classList.remove("ring-2", "ring-red-400"), 1500)
    } finally {
      input.disabled = false
      input.focus()
      this._saving = false
    }
  }

  changeSection(event) {
    const sectionId = event.target.value
    if (!sectionId) return

    const url = new URL(window.location.href)
    url.searchParams.set("section_id", sectionId)
    window.location.href = url.toString()
  }

  autoResizeInput() {
    if (!this.hasTitleInputTarget) return
    const input = this.titleInputTarget
    input.style.height = "auto"
    input.style.height = input.scrollHeight + "px"
  }

  updateCounters() {
    if (this.hasSessionCountTarget) {
      this.sessionCountTarget.textContent = this._sessionCount
    }
    if (this.hasTotalCountTarget) {
      const current = parseInt(this.totalCountTarget.textContent, 10) || 0
      this.totalCountTarget.textContent = current + 1
    }
  }
}
