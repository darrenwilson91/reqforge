import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "selectedId", "selectedDisplay", "form", "panel"]
  static values = { url: String, excludeId: String }

  connect() {
    this.debounceTimer = null
    this.open = false
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
  }

  toggle() {
    if (this.open) {
      this.close()
    } else {
      this.panelTarget.classList.remove("hidden")
      this.open = true
      this.inputTarget.focus()
    }
  }

  close() {
    this.panelTarget.classList.add("hidden")
    this.open = false
    this.clearSearch()
  }

  onInput() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.search(), 250)
  }

  async search() {
    const query = this.inputTarget.value.trim()
    if (query.length < 1) {
      this.resultsTarget.replaceChildren()
      return
    }

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)
    if (this.excludeIdValue) {
      url.searchParams.set("exclude_id", this.excludeIdValue)
    }

    try {
      const response = await fetch(url, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })
      if (response.ok) {
        const html = await response.text()
        // Parse server-rendered HTML safely using the browser's DOM parser
        const template = document.createElement("template")
        template.innerHTML = html
        this.resultsTarget.replaceChildren(template.content)
      }
    } catch (e) {
      // Silently fail on network errors
    }
  }

  select(event) {
    const item = event.currentTarget
    const id = item.dataset.requirementId
    const uid = item.dataset.requirementUid
    const title = item.dataset.requirementTitle

    this.selectedIdTarget.value = id

    const uidSpan = document.createElement("span")
    uidSpan.className = "rf-uid text-xs"
    uidSpan.textContent = uid

    const titleSpan = document.createElement("span")
    titleSpan.className = "ml-2 text-sm text-slate-700"
    titleSpan.textContent = title

    this.selectedDisplayTarget.replaceChildren(uidSpan, titleSpan)
    this.selectedDisplayTarget.classList.remove("hidden")

    this.resultsTarget.replaceChildren()
    this.inputTarget.value = ""
  }

  clearSelection() {
    this.selectedIdTarget.value = ""
    this.selectedDisplayTarget.replaceChildren()
    this.selectedDisplayTarget.classList.add("hidden")
  }

  clearSearch() {
    this.inputTarget.value = ""
    this.resultsTarget.replaceChildren()
    this.clearSelection()
  }
}
