import { Controller } from "@hotwired/stimulus"

// Manages an expandable/collapsible tree hierarchy for requirements navigation.
// Nodes with children can be toggled open/closed. The active requirement is highlighted.
export default class extends Controller {
  static targets = ["node", "children", "toggle"]
  static values = {
    activeId: String
  }

  connect() {
    // Expand nodes that contain the active requirement
    if (this.activeIdValue) {
      this.revealActive()
    }
  }

  toggle(event) {
    const button = event.currentTarget
    const nodeId = button.dataset.treeNodeId
    const childrenEl = this.findChildren(nodeId)
    const icon = button.querySelector("[data-tree-icon]")

    if (!childrenEl) return

    const isExpanded = childrenEl.dataset.expanded === "true"

    if (isExpanded) {
      childrenEl.classList.add("hidden")
      childrenEl.dataset.expanded = "false"
      if (icon) icon.style.transform = "rotate(0deg)"
    } else {
      childrenEl.classList.remove("hidden")
      childrenEl.dataset.expanded = "true"
      if (icon) icon.style.transform = "rotate(90deg)"
    }
  }

  expandAll() {
    this.childrenTargets.forEach(el => {
      el.classList.remove("hidden")
      el.dataset.expanded = "true"
    })
    this.element.querySelectorAll("[data-tree-icon]").forEach(icon => {
      icon.style.transform = "rotate(90deg)"
    })
  }

  collapseAll() {
    this.childrenTargets.forEach(el => {
      el.classList.add("hidden")
      el.dataset.expanded = "false"
    })
    this.element.querySelectorAll("[data-tree-icon]").forEach(icon => {
      icon.style.transform = "rotate(0deg)"
    })
  }

  // Expand all ancestor nodes of the active requirement
  revealActive() {
    const activeEl = this.element.querySelector(
      `[data-tree-requirement-id="${this.activeIdValue}"]`
    )
    if (!activeEl) return

    let parent = activeEl.parentElement
    while (parent && parent !== this.element) {
      if (parent.dataset.treeTarget === "children") {
        parent.classList.remove("hidden")
        parent.dataset.expanded = "true"
        // Rotate the toggle icon for the parent node
        const nodeId = parent.dataset.treeChildrenId
        const toggleBtn = this.element.querySelector(
          `[data-tree-node-id="${nodeId}"]`
        )
        if (toggleBtn) {
          const icon = toggleBtn.querySelector("[data-tree-icon]")
          if (icon) icon.style.transform = "rotate(90deg)"
        }
      }
      parent = parent.parentElement
    }
  }

  findChildren(nodeId) {
    return this.childrenTargets.find(
      el => el.dataset.treeChildrenId === nodeId
    )
  }
}
