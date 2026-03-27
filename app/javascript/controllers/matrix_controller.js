import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cell", "rowHeader", "colHeader", "tooltip"]

  connect() {
    this._hideTooltip = this._hideTooltip.bind(this)
  }

  highlightRow(event) {
    const row = event.currentTarget.dataset.matrixRow
    if (!row) return

    this.cellTargets.forEach(cell => {
      if (cell.dataset.matrixRow === row) {
        cell.classList.add("ring-2", "ring-brand-accent/40")
      }
    })

    this.rowHeaderTargets.forEach(header => {
      if (header.dataset.matrixRow === row) {
        header.classList.add("bg-amber-50")
      }
    })
  }

  unhighlightRow(event) {
    const row = event.currentTarget.dataset.matrixRow
    if (!row) return

    this.cellTargets.forEach(cell => {
      if (cell.dataset.matrixRow === row) {
        cell.classList.remove("ring-2", "ring-brand-accent/40")
      }
    })

    this.rowHeaderTargets.forEach(header => {
      if (header.dataset.matrixRow === row) {
        header.classList.remove("bg-amber-50")
      }
    })
  }

  highlightCol(event) {
    const col = event.currentTarget.dataset.matrixCol
    if (!col) return

    this.cellTargets.forEach(cell => {
      if (cell.dataset.matrixCol === col) {
        cell.classList.add("ring-2", "ring-brand-accent/40")
      }
    })

    this.colHeaderTargets.forEach(header => {
      if (header.dataset.matrixCol === col) {
        header.classList.add("bg-amber-50")
      }
    })
  }

  unhighlightCol(event) {
    const col = event.currentTarget.dataset.matrixCol
    if (!col) return

    this.cellTargets.forEach(cell => {
      if (cell.dataset.matrixCol === col) {
        cell.classList.remove("ring-2", "ring-brand-accent/40")
      }
    })

    this.colHeaderTargets.forEach(header => {
      if (header.dataset.matrixCol === col) {
        header.classList.remove("bg-amber-50")
      }
    })
  }

  showTooltip(event) {
    const cell = event.currentTarget
    const linkTypes = cell.dataset.matrixLinkTypes
    if (!linkTypes) return

    const tooltip = this.tooltipTarget
    const sourceUid = cell.dataset.matrixSourceUid
    const targetUid = cell.dataset.matrixTargetUid
    const types = linkTypes.split(",")

    let content = document.createElement("div")

    let header = document.createElement("div")
    header.className = "font-semibold text-slate-900 mb-1 text-xs"
    header.textContent = `${sourceUid} → ${targetUid}`
    content.appendChild(header)

    types.forEach(type => {
      let tag = document.createElement("span")
      tag.className = "inline-block px-1.5 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-600 mr-1 mb-1"
      tag.textContent = type.replace(/_/g, " ")
      content.appendChild(tag)
    })

    tooltip.replaceChildren(content)
    tooltip.classList.remove("hidden")

    const rect = cell.getBoundingClientRect()
    const containerRect = this.element.getBoundingClientRect()
    tooltip.style.left = `${rect.left - containerRect.left + rect.width / 2}px`
    tooltip.style.top = `${rect.top - containerRect.top - 8}px`
    tooltip.style.transform = "translate(-50%, -100%)"
  }

  hideTooltip() {
    this._hideTooltip()
  }

  _hideTooltip() {
    if (this.hasTooltipTarget) {
      this.tooltipTarget.classList.add("hidden")
    }
  }
}
