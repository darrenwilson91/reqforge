import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropdown", "results"]
  static values = { url: String }

  connect() {
    this._debounceTimer = null
    this._open = false

    // Close dropdown on outside click
    this._outsideClick = (event) => {
      if (!this.element.contains(event.target)) {
        this.close()
      }
    }
    document.addEventListener("click", this._outsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClick)
    if (this._debounceTimer) clearTimeout(this._debounceTimer)
  }

  search() {
    const query = this.inputTarget.value.trim()

    if (this._debounceTimer) clearTimeout(this._debounceTimer)

    if (query.length < 2) {
      this.close()
      return
    }

    this._debounceTimer = setTimeout(() => {
      this._fetchResults(query)
    }, 250)
  }

  submit(event) {
    event.preventDefault()
    const query = this.inputTarget.value.trim()
    if (query.length > 0) {
      window.location.href = `/search?q=${encodeURIComponent(query)}`
    }
  }

  close() {
    this._open = false
    this.dropdownTarget.classList.add("hidden")
  }

  selectResult() {
    // Mousedown fires before blur — allow the link navigation to proceed
    this._open = false
  }

  blur() {
    // Delay closing so mousedown on results can fire first
    setTimeout(() => {
      if (!this._open) return
      this.close()
    }, 150)
  }

  async _fetchResults(query) {
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (!response.ok) return

      const html = await response.text()

      // Use DOM parser to safely insert server-rendered HTML
      const doc = new DOMParser().parseFromString(html, "text/html")
      this.resultsTarget.replaceChildren(...doc.body.childNodes)

      this.dropdownTarget.classList.remove("hidden")
      this._open = true
    } catch (e) {
      // Silently fail — search is non-critical
    }
  }
}
