import { Controller } from "@hotwired/stimulus"

// Enum options for attribute selectors
const ATTRIBUTE_OPTIONS = {
  requirement_type: [
    { value: "functional", label: "Functional" },
    { value: "non_functional", label: "Non-Functional" },
    { value: "safety", label: "Safety" },
    { value: "interface", label: "Interface" },
    { value: "design_constraint", label: "Design Constraint" }
  ],
  priority: [
    { value: "must_have", label: "Must Have" },
    { value: "should_have", label: "Should Have" },
    { value: "could_have", label: "Could Have" },
    { value: "wont_have", label: "Won't Have" }
  ],
  asil_level: [
    { value: "qm", label: "QM" },
    { value: "asil_a", label: "ASIL A" },
    { value: "asil_b", label: "ASIL B" },
    { value: "asil_c", label: "ASIL C" },
    { value: "asil_d", label: "ASIL D" }
  ]
}

const ATTRIBUTE_FIELDS = ["requirement_type", "priority", "asil_level"]

export default class extends Controller {
  static targets = ["titleInput", "sectionSelect", "sectionSwitcher", "nextUid", "sessionCount", "totalCount", "inputArea", "actionBar", "attributeBar", "attrTypeBadge", "attrPriorityBadge", "attrAsilBadge", "requirementList"]
  static values = { url: String, section: String, deleteUrl: String }

  connect() {
    this._sessionCount = 0
    this._saving = false
    this._attributeBarOpen = false
    this._activeFieldIndex = 0
    this._selectedIndices = { requirement_type: 0, priority: 0, asil_level: 0 }
    this._selectedRowIndex = -1 // -1 means no row selected (input area is focused)
    this.autoResizeInput()
    this._updateDefaultBadges()
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.createRequirement()
      return
    }

    if (event.key === "Tab" && !event.shiftKey) {
      const input = this.titleInputTarget
      if (input.value.trim() === "" && !this._attributeBarOpen) {
        event.preventDefault()
        this._openAttributeBar()
        return
      }
    }

    // Up arrow from empty input: navigate to last requirement row
    if (event.key === "ArrowUp" && this.titleInputTarget.value.trim() === "") {
      const rows = this._getRequirementRows()
      if (rows.length > 0) {
        event.preventDefault()
        this._selectRow(rows.length - 1)
      }
      return
    }
    // Shift+Enter: default textarea behavior (newline) — no action needed
  }

  handleRowKeydown(event) {
    if (this._selectedRowIndex < 0) return
    const rows = this._getRequirementRows()

    switch (event.key) {
      case "ArrowUp":
        event.preventDefault()
        if (this._selectedRowIndex > 0) {
          this._selectRow(this._selectedRowIndex - 1)
        }
        break
      case "ArrowDown":
        event.preventDefault()
        if (this._selectedRowIndex < rows.length - 1) {
          this._selectRow(this._selectedRowIndex + 1)
        } else {
          // Past the last row: return focus to input
          this._deselectAllRows()
          this.titleInputTarget.focus()
        }
        break
      case "Backspace":
      case "Delete":
        event.preventDefault()
        this._deleteSelectedRow()
        break
      case "Escape":
        event.preventDefault()
        this._deselectAllRows()
        this.titleInputTarget.focus()
        break
    }
  }

  handleAttributeKeydown(event) {
    if (!this._attributeBarOpen) return

    switch (event.key) {
      case "ArrowLeft":
      case "ArrowUp":
        event.preventDefault()
        this._cycleSelectorValue(-1)
        break
      case "ArrowRight":
      case "ArrowDown":
        event.preventDefault()
        this._cycleSelectorValue(1)
        break
      case "Tab":
        event.preventDefault()
        if (event.shiftKey) {
          this._moveSelectorFocus(-1)
        } else {
          this._moveSelectorFocus(1)
        }
        break
      case "Enter":
        event.preventDefault()
        this._closeAttributeBar()
        break
      case "Escape":
        event.preventDefault()
        this._closeAttributeBar()
        break
    }
  }

  closeAttributeBar() {
    this._closeAttributeBar()
  }

  // Row navigation helpers

  _getRequirementRows() {
    if (!this.hasRequirementListTarget) return []
    return Array.from(this.requirementListTarget.querySelectorAll("[data-requirement-id]"))
  }

  _selectRow(index) {
    const rows = this._getRequirementRows()
    if (index < 0 || index >= rows.length) return

    this._deselectAllRows()
    this._selectedRowIndex = index
    const row = rows[index]
    row.classList.add("ring-2", "ring-brand-accent/40", "bg-amber-50/50", "dark:bg-amber-900/10")
    row.setAttribute("tabindex", "0")
    row.focus()
  }

  _deselectAllRows() {
    this._selectedRowIndex = -1
    const rows = this._getRequirementRows()
    rows.forEach(row => {
      row.classList.remove("ring-2", "ring-brand-accent/40", "bg-amber-50/50", "dark:bg-amber-900/10")
      row.removeAttribute("tabindex")
    })
  }

  async _deleteSelectedRow() {
    const rows = this._getRequirementRows()
    if (this._selectedRowIndex < 0 || this._selectedRowIndex >= rows.length) return

    const row = rows[this._selectedRowIndex]
    const requirementId = row.dataset.requirementId
    const titleEl = row.querySelector("p")
    const title = titleEl ? titleEl.textContent.trim() : ""

    // Confirm deletion — always confirm since these are saved requirements
    const message = title
      ? `Delete requirement "${title.substring(0, 60)}${title.length > 60 ? '...' : ''}"?`
      : "Delete this requirement?"
    if (!confirm(message)) return

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch(this.deleteUrlValue.replace("__ID__", requirementId), {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": token,
          "Accept": "text/html"
        }
      })

      if (response.ok || response.redirected) {
        // Remove the row from DOM
        row.remove()

        // Update total count
        if (this.hasTotalCountTarget) {
          const current = parseInt(this.totalCountTarget.textContent, 10) || 0
          if (current > 0) this.totalCountTarget.textContent = current - 1
        }

        // Navigate to adjacent row or input
        const updatedRows = this._getRequirementRows()
        if (updatedRows.length === 0) {
          this._selectedRowIndex = -1
          this.titleInputTarget.focus()
        } else if (this._selectedRowIndex >= updatedRows.length) {
          this._selectRow(updatedRows.length - 1)
        } else {
          this._selectRow(this._selectedRowIndex)
        }
      } else {
        // Flash error on the row
        row.classList.add("ring-2", "ring-red-400")
        setTimeout(() => row.classList.remove("ring-2", "ring-red-400"), 1500)
      }
    } catch (error) {
      row.classList.add("ring-2", "ring-red-400")
      setTimeout(() => row.classList.remove("ring-2", "ring-red-400"), 1500)
    }
  }

  _openAttributeBar() {
    if (!this.hasAttributeBarTarget) return
    this._attributeBarOpen = true
    this._activeFieldIndex = 0

    this.attributeBarTarget.classList.remove("hidden")
    this._renderAttributeBar()
    this.attributeBarTarget.focus()
  }

  _closeAttributeBar() {
    if (!this.hasAttributeBarTarget) return
    this._attributeBarOpen = false
    this.attributeBarTarget.classList.add("hidden")
    this._updateDefaultBadges()
    this.titleInputTarget.focus()
  }

  _cycleSelectorValue(direction) {
    const field = ATTRIBUTE_FIELDS[this._activeFieldIndex]
    const options = ATTRIBUTE_OPTIONS[field]
    const current = this._selectedIndices[field]
    const next = (current + direction + options.length) % options.length
    this._selectedIndices[field] = next
    this._renderAttributeBar()
  }

  _moveSelectorFocus(direction) {
    const next = this._activeFieldIndex + direction
    if (next < 0 || next >= ATTRIBUTE_FIELDS.length) {
      // Tabbing past the last or before the first closes the bar
      this._closeAttributeBar()
      return
    }
    this._activeFieldIndex = next
    this._renderAttributeBar()
  }

  _renderAttributeBar() {
    if (!this.hasAttributeBarTarget) return
    const bar = this.attributeBarTarget

    // Clear and rebuild using safe DOM methods
    while (bar.firstChild) bar.removeChild(bar.firstChild)

    ATTRIBUTE_FIELDS.forEach((field, fieldIdx) => {
      const options = ATTRIBUTE_OPTIONS[field]
      const selectedIdx = this._selectedIndices[field]
      const isActive = fieldIdx === this._activeFieldIndex

      const group = document.createElement("div")
      group.className = "flex items-center gap-1.5"

      // Field label
      const label = document.createElement("span")
      label.className = "text-[10px] uppercase tracking-wider font-semibold " +
        (isActive ? "text-brand-accent" : "text-slate-400 dark:text-slate-500")
      label.textContent = field === "requirement_type" ? "Type" :
        field === "priority" ? "Priority" : "ASIL"
      group.appendChild(label)

      // Value display with arrows
      const valueWrap = document.createElement("div")
      valueWrap.className = "flex items-center gap-0.5 " +
        (isActive ? "ring-1 ring-brand-accent/50 rounded-md" : "")

      const leftArrow = document.createElement("span")
      leftArrow.className = "text-[10px] px-0.5 " +
        (isActive ? "text-brand-accent" : "text-slate-300 dark:text-slate-600")
      leftArrow.textContent = "\u25C0"
      valueWrap.appendChild(leftArrow)

      const valueBadge = document.createElement("span")
      valueBadge.className = "inline-block px-2 py-0.5 text-xs font-medium rounded " +
        (isActive
          ? "bg-brand-accent/10 text-brand-accent-dark dark:text-brand-accent border border-brand-accent/30"
          : "bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300")
      valueBadge.textContent = options[selectedIdx].label
      valueWrap.appendChild(valueBadge)

      const rightArrow = document.createElement("span")
      rightArrow.className = "text-[10px] px-0.5 " +
        (isActive ? "text-brand-accent" : "text-slate-300 dark:text-slate-600")
      rightArrow.textContent = "\u25B6"
      valueWrap.appendChild(rightArrow)

      group.appendChild(valueWrap)
      bar.appendChild(group)

      // Add separator between fields
      if (fieldIdx < ATTRIBUTE_FIELDS.length - 1) {
        const sep = document.createElement("span")
        sep.className = "text-slate-200 dark:text-slate-700 mx-1"
        sep.textContent = "\u00B7"
        bar.appendChild(sep)
      }
    })

    // Keyboard hints
    const hints = document.createElement("span")
    hints.className = "text-[10px] text-slate-400 dark:text-slate-500 ml-2"
    hints.textContent = "\u2190\u2192 cycle \u00B7 Tab next \u00B7 Enter/Esc close"
    bar.appendChild(hints)
  }

  _getSelectedAttributes() {
    return {
      requirement_type: ATTRIBUTE_OPTIONS.requirement_type[this._selectedIndices.requirement_type].value,
      priority: ATTRIBUTE_OPTIONS.priority[this._selectedIndices.priority].value,
      asil_level: ATTRIBUTE_OPTIONS.asil_level[this._selectedIndices.asil_level].value
    }
  }

  _updateDefaultBadges() {
    const attrs = this._getSelectedAttributes()

    if (this.hasAttrTypeBadgeTarget) {
      this.attrTypeBadgeTarget.textContent = ATTRIBUTE_OPTIONS.requirement_type[this._selectedIndices.requirement_type].label
    }
    if (this.hasAttrPriorityBadgeTarget) {
      this.attrPriorityBadgeTarget.textContent = ATTRIBUTE_OPTIONS.priority[this._selectedIndices.priority].label
    }
    if (this.hasAttrAsilBadgeTarget) {
      this.attrAsilBadgeTarget.textContent = ATTRIBUTE_OPTIONS.asil_level[this._selectedIndices.asil_level].label
    }
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

    const attrs = this._getSelectedAttributes()

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
          section_id: sectionId,
          requirement_type: attrs.requirement_type,
          priority: attrs.priority,
          asil_level: attrs.asil_level
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
