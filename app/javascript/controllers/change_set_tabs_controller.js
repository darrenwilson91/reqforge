import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { activeTab: { type: String, default: "changes" } }

  connect() {
    this.showTab(this.activeTabValue)
  }

  switchTab(event) {
    const tabName = event.currentTarget.dataset.tab
    this.activeTabValue = tabName
    this.showTab(tabName)
  }

  showTab(tabName) {
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tab === tabName
      tab.classList.toggle("border-brand-accent", isActive)
      tab.classList.toggle("text-brand-accent", isActive)
      tab.classList.toggle("border-transparent", !isActive)
      tab.classList.toggle("text-slate-500", !isActive)
    })

    this.panelTargets.forEach(panel => {
      panel.classList.toggle("hidden", panel.dataset.tab !== tabName)
    })
  }
}
