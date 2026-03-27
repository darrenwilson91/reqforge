import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "selectAll", "toolbar", "selectedCount", "cell"]

  connect() {
    this.lastCheckedIndex = null
    this.originalCellContents = new Map()
  }

  // Checkbox: toggle single row
  toggleRow(event) {
    const checkbox = event.currentTarget
    const row = checkbox.closest("tr")

    if (event.shiftKey && this.lastCheckedIndex !== null) {
      this.shiftSelect(checkbox)
    }

    this.lastCheckedIndex = this.rowTargets.indexOf(row)
    this.updateToolbar()
  }

  // Checkbox: select/deselect all
  toggleAll(event) {
    const checked = event.currentTarget.checked
    this.rowTargets.forEach(row => {
      const cb = row.querySelector('input[type="checkbox"]')
      if (cb) cb.checked = checked
    })
    this.updateToolbar()
  }

  // Shift+click range select
  shiftSelect(checkbox) {
    const row = checkbox.closest("tr")
    const currentIndex = this.rowTargets.indexOf(row)
    const start = Math.min(this.lastCheckedIndex, currentIndex)
    const end = Math.max(this.lastCheckedIndex, currentIndex)
    const checked = checkbox.checked

    for (let i = start; i <= end; i++) {
      const cb = this.rowTargets[i].querySelector('input[type="checkbox"]')
      if (cb) cb.checked = checked
    }
  }

  // Update toolbar visibility and selected count
  updateToolbar() {
    const selected = this.getSelectedIds()
    const count = selected.length

    if (this.hasToolbarTarget) {
      this.toolbarTarget.classList.toggle("hidden", count === 0)
    }
    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = `${count} selected`
    }
    if (this.hasSelectAllTarget) {
      const total = this.rowTargets.length
      this.selectAllTarget.checked = count === total && total > 0
      this.selectAllTarget.indeterminate = count > 0 && count < total
    }
  }

  // Inline edit: make a cell editable on click
  editCell(event) {
    const cell = event.currentTarget
    if (cell.dataset.editing === "true") return

    const type = cell.dataset.fieldType
    const field = cell.dataset.field
    const value = cell.dataset.value
    const reqId = cell.closest("tr").dataset.requirementId

    cell.dataset.editing = "true"

    // Save original children for cancel
    const cellKey = `${reqId}-${field}`
    const fragment = document.createDocumentFragment()
    Array.from(cell.childNodes).forEach(node => fragment.appendChild(node.cloneNode(true)))
    this.originalCellContents.set(cellKey, fragment)

    if (type === "select") {
      this.showSelectEditor(cell, field, value, reqId)
    } else {
      this.showTextEditor(cell, field, value, reqId)
    }
  }

  showTextEditor(cell, field, value, reqId) {
    const input = document.createElement("input")
    input.type = "text"
    input.value = value
    input.className = "w-full px-2 py-1 text-sm border border-brand-accent rounded focus:outline-none focus:ring-2 focus:ring-brand-accent"
    input.dataset.originalValue = value
    input.dataset.field = field
    input.dataset.reqId = reqId

    input.addEventListener("keydown", (e) => this.handleEditorKeydown(e, cell))
    input.addEventListener("blur", (e) => this.commitEdit(e.target, cell))

    cell.replaceChildren(input)
    input.focus()
    input.select()
  }

  showSelectEditor(cell, field, value, reqId) {
    const options = JSON.parse(cell.dataset.options || "[]")

    const select = document.createElement("select")
    select.className = "w-full px-1 py-1 text-sm border border-brand-accent rounded focus:outline-none focus:ring-2 focus:ring-brand-accent"
    select.dataset.originalValue = value
    select.dataset.field = field
    select.dataset.reqId = reqId

    options.forEach(([label, val]) => {
      const opt = document.createElement("option")
      opt.value = val
      opt.textContent = label
      if (val === value) opt.selected = true
      select.appendChild(opt)
    })

    select.addEventListener("keydown", (e) => this.handleEditorKeydown(e, cell))
    select.addEventListener("change", (e) => this.commitEdit(e.target, cell))
    select.addEventListener("blur", (e) => this.commitEdit(e.target, cell))

    cell.replaceChildren(select)
    select.focus()
  }

  handleEditorKeydown(event, cell) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.commitEdit(event.target, cell)
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.cancelEdit(event.target, cell)
    } else if (event.key === "Tab") {
      event.preventDefault()
      this.commitEdit(event.target, cell)
      this.moveToNextCell(cell, event.shiftKey)
    }
  }

  commitEdit(editor, cell) {
    if (cell.dataset.editing !== "true") return
    const newValue = editor.value
    const originalValue = editor.dataset.originalValue
    const field = editor.dataset.field
    const reqId = editor.dataset.reqId

    cell.dataset.editing = "false"

    if (newValue !== originalValue) {
      cell.dataset.value = newValue
      const hiddenInput = this.element.querySelector(`input[name="requirements[${reqId}][${field}]"]`)
      if (hiddenInput) hiddenInput.value = newValue

      const row = cell.closest("tr")
      row.classList.add("bg-amber-50/50")
      row.dataset.changed = "true"
    }

    this.renderCellDisplay(cell, field, newValue)
  }

  cancelEdit(editor, cell) {
    const field = editor.dataset.field
    const reqId = editor.dataset.reqId
    const cellKey = `${reqId}-${field}`

    cell.dataset.editing = "false"

    const saved = this.originalCellContents.get(cellKey)
    if (saved) {
      cell.replaceChildren(saved)
      this.originalCellContents.delete(cellKey)
    } else {
      this.renderCellDisplay(cell, field, cell.dataset.value)
    }
  }

  renderCellDisplay(cell, field, value) {
    if (cell.dataset.fieldType === "select") {
      const options = JSON.parse(cell.dataset.options || "[]")
      const match = options.find(([, v]) => v === value)
      const label = match ? match[0] : value

      const span = document.createElement("span")
      span.className = cell.dataset.badgeClass || "text-sm text-slate-700"
      span.textContent = label
      cell.replaceChildren(span)
    } else {
      cell.replaceChildren(document.createTextNode(value))
    }
  }

  moveToNextCell(currentCell, reverse) {
    const cells = Array.from(this.element.querySelectorAll("[data-bulk-edit-target='cell']"))
    const currentIndex = cells.indexOf(currentCell)
    const nextIndex = reverse ? currentIndex - 1 : currentIndex + 1

    if (nextIndex >= 0 && nextIndex < cells.length) {
      cells[nextIndex].click()
    }
  }

  // Bulk actions
  openBulkAction(event) {
    const action = event.currentTarget.dataset.bulkAction
    const popover = this.element.querySelector(`[data-popover="${action}"]`)
    if (!popover) return

    this.element.querySelectorAll("[data-popover]").forEach(p => {
      if (p !== popover) p.classList.add("hidden")
    })
    popover.classList.toggle("hidden")
  }

  applyBulkAction(event) {
    const field = event.currentTarget.dataset.field
    const value = event.currentTarget.closest("[data-popover]").querySelector("select").value
    const selectedIds = this.getSelectedIds()

    selectedIds.forEach(id => {
      const hiddenInput = this.element.querySelector(`input[name="requirements[${id}][${field}]"]`)
      if (hiddenInput) hiddenInput.value = value

      const row = this.element.querySelector(`tr[data-requirement-id="${id}"]`)
      if (row) {
        row.classList.add("bg-amber-50/50")
        row.dataset.changed = "true"
        const cell = row.querySelector(`[data-field="${field}"]`)
        if (cell) {
          cell.dataset.value = value
          this.renderCellDisplay(cell, field, value)
        }
      }
    })

    event.currentTarget.closest("[data-popover]").classList.add("hidden")
  }

  bulkDelete(event) {
    const selectedIds = this.getSelectedIds()
    if (selectedIds.length === 0) return

    if (!confirm(`Delete ${selectedIds.length} selected requirement(s)? This cannot be undone.`)) return

    const form = document.createElement("form")
    form.method = "POST"
    form.action = this.element.dataset.bulkDeleteUrl

    const methodInput = document.createElement("input")
    methodInput.type = "hidden"
    methodInput.name = "_method"
    methodInput.value = "delete"
    form.appendChild(methodInput)

    const tokenInput = document.createElement("input")
    tokenInput.type = "hidden"
    tokenInput.name = "authenticity_token"
    tokenInput.value = document.querySelector('meta[name="csrf-token"]').content
    form.appendChild(tokenInput)

    selectedIds.forEach(id => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "requirement_ids[]"
      input.value = id
      form.appendChild(input)
    })

    document.body.appendChild(form)
    form.submit()
  }

  // Helpers
  getSelectedIds() {
    return this.rowTargets
      .filter(row => row.querySelector('input[type="checkbox"]')?.checked)
      .map(row => row.dataset.requirementId)
  }
}
