import { Controller } from "@hotwired/stimulus"

// Manages dynamic custom attribute definitions for project schemas.
// Each attribute has: name (string), attr_type (string/integer/boolean/float/enum/date), required (boolean).
// Enum types additionally store an options array.
export default class extends Controller {
  static targets = ["container", "template", "hiddenField"]
  static values = { attributes: { type: Array, default: [] } }

  connect() {
    this.renderAll()
  }

  attributesValueChanged() {
    this.syncHiddenField()
  }

  addAttribute() {
    const attrs = [...this.attributesValue]
    attrs.push({ name: "", attr_type: "string", required: false, options: [] })
    this.attributesValue = attrs
    this.renderAll()
    const inputs = this.containerTarget.querySelectorAll("[data-field='name']")
    if (inputs.length > 0) {
      inputs[inputs.length - 1].focus()
    }
  }

  removeAttribute(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    const attrs = [...this.attributesValue]
    attrs.splice(index, 1)
    this.attributesValue = attrs
    this.renderAll()
  }

  updateName(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    const attrs = [...this.attributesValue]
    attrs[index] = { ...attrs[index], name: event.currentTarget.value }
    this.attributesValue = attrs
  }

  updateType(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    const attrs = [...this.attributesValue]
    attrs[index] = { ...attrs[index], attr_type: event.currentTarget.value, options: [] }
    this.attributesValue = attrs
    this.renderAll()
  }

  updateRequired(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    const attrs = [...this.attributesValue]
    attrs[index] = { ...attrs[index], required: event.currentTarget.checked }
    this.attributesValue = attrs
  }

  updateOptions(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    const attrs = [...this.attributesValue]
    const options = event.currentTarget.value.split(",").map(o => o.trim()).filter(o => o.length > 0)
    attrs[index] = { ...attrs[index], options }
    this.attributesValue = attrs
  }

  syncHiddenField() {
    if (this.hasHiddenFieldTarget) {
      this.hiddenFieldTarget.value = JSON.stringify(this.attributesValue)
    }
  }

  renderAll() {
    const attrs = this.attributesValue
    const container = this.containerTarget
    container.replaceChildren()

    if (attrs.length === 0) {
      const empty = document.createElement("div")
      empty.className = "text-sm text-slate-400 py-4 text-center border border-dashed border-slate-200 rounded-lg"
      empty.textContent = 'No custom attributes defined. Click "Add Attribute" to define project-specific fields.'
      container.appendChild(empty)
      return
    }

    attrs.forEach((attr, index) => {
      container.appendChild(this.buildRow(attr, index))
    })

    this.syncHiddenField()
  }

  buildRow(attr, index) {
    const row = document.createElement("div")
    row.className = "flex items-start gap-3 p-3 bg-slate-50 rounded-lg border border-slate-200"

    const fields = document.createElement("div")
    fields.className = "flex-1 grid grid-cols-1 sm:grid-cols-3 gap-3"

    // Name field
    const nameGroup = this.buildFieldGroup("Name")
    const nameInput = document.createElement("input")
    nameInput.type = "text"
    nameInput.value = attr.name
    nameInput.dataset.field = "name"
    nameInput.dataset.index = index
    nameInput.dataset.action = "input->attribute-schema#updateName"
    nameInput.placeholder = "e.g. Verification Method"
    nameInput.className = "rf-input mt-1 text-sm"
    nameGroup.appendChild(nameInput)
    fields.appendChild(nameGroup)

    // Type field
    const typeGroup = this.buildFieldGroup("Type")
    const typeSelect = document.createElement("select")
    typeSelect.dataset.field = "attr_type"
    typeSelect.dataset.index = index
    typeSelect.dataset.action = "change->attribute-schema#updateType"
    typeSelect.className = "rf-input mt-1 text-sm"
    const typeOptions = [
      ["string", "Text"], ["integer", "Integer"], ["float", "Decimal"],
      ["boolean", "Yes/No"], ["date", "Date"], ["enum", "Enum (list)"]
    ]
    typeOptions.forEach(([value, label]) => {
      const opt = document.createElement("option")
      opt.value = value
      opt.textContent = label
      opt.selected = attr.attr_type === value
      typeSelect.appendChild(opt)
    })
    typeGroup.appendChild(typeSelect)
    fields.appendChild(typeGroup)

    // Required checkbox
    const reqGroup = document.createElement("div")
    reqGroup.className = "flex items-end gap-3"
    const reqLabel = document.createElement("label")
    reqLabel.className = "flex items-center gap-2 text-sm text-slate-600 pb-2 cursor-pointer"
    const reqCheckbox = document.createElement("input")
    reqCheckbox.type = "checkbox"
    reqCheckbox.checked = attr.required
    reqCheckbox.dataset.field = "required"
    reqCheckbox.dataset.index = index
    reqCheckbox.dataset.action = "change->attribute-schema#updateRequired"
    reqCheckbox.className = "rounded border-slate-300 text-amber-500 focus:ring-amber-500"
    reqLabel.appendChild(reqCheckbox)
    reqLabel.appendChild(document.createTextNode(" Required"))
    reqGroup.appendChild(reqLabel)
    fields.appendChild(reqGroup)

    // Enum options (conditional)
    if (attr.attr_type === "enum") {
      const enumGroup = document.createElement("div")
      enumGroup.className = "w-full mt-2 sm:col-span-3"
      const enumLabel = document.createElement("label")
      enumLabel.className = "text-xs text-slate-500 font-medium"
      enumLabel.textContent = "Options (comma-separated)"
      enumGroup.appendChild(enumLabel)
      const enumInput = document.createElement("input")
      enumInput.type = "text"
      enumInput.value = (attr.options || []).join(", ")
      enumInput.dataset.field = "options"
      enumInput.dataset.index = index
      enumInput.dataset.action = "input->attribute-schema#updateOptions"
      enumInput.placeholder = "e.g. Low, Medium, High"
      enumInput.className = "rf-input mt-1 text-sm"
      enumGroup.appendChild(enumInput)
      fields.appendChild(enumGroup)
    }

    row.appendChild(fields)

    // Remove button
    const removeBtn = document.createElement("button")
    removeBtn.type = "button"
    removeBtn.dataset.index = index
    removeBtn.dataset.action = "click->attribute-schema#removeAttribute"
    removeBtn.className = "mt-5 p-1.5 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded transition-colors"
    removeBtn.title = "Remove attribute"
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    svg.setAttribute("class", "w-4 h-4")
    svg.setAttribute("viewBox", "0 0 20 20")
    svg.setAttribute("fill", "currentColor")
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
    path.setAttribute("fill-rule", "evenodd")
    path.setAttribute("d", "M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z")
    path.setAttribute("clip-rule", "evenodd")
    svg.appendChild(path)
    removeBtn.appendChild(svg)
    row.appendChild(removeBtn)

    return row
  }

  buildFieldGroup(labelText) {
    const group = document.createElement("div")
    const label = document.createElement("label")
    label.className = "text-xs text-slate-500 font-medium"
    label.textContent = labelText
    group.appendChild(label)
    return group
  }
}
