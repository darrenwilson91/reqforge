import { Controller } from "@hotwired/stimulus"

// Manages dark/light theme preference.
// Persists to localStorage and applies to <html> element.
export default class extends Controller {
  static targets = ["sunIcon", "moonIcon"]

  connect() {
    this.applyTheme()
  }

  toggle() {
    const isDark = document.documentElement.classList.contains("dark")
    const newTheme = isDark ? "light" : "dark"
    localStorage.setItem("reqforge-theme", newTheme)
    this.applyTheme()
  }

  applyTheme() {
    const stored = localStorage.getItem("reqforge-theme")
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    const isDark = stored === "dark" || (!stored && prefersDark)

    document.documentElement.classList.toggle("dark", isDark)
    this.updateIcons(isDark)
  }

  updateIcons(isDark) {
    if (this.hasSunIconTarget) {
      this.sunIconTarget.classList.toggle("hidden", !isDark)
    }
    if (this.hasMoonIconTarget) {
      this.moonIconTarget.classList.toggle("hidden", isDark)
    }
  }
}
