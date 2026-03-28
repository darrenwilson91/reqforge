import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Drag-and-drop reordering for requirements within sections.
// Connects to a container element whose children are draggable requirement items.
// On drop, sends the new ordering to the server via a PATCH request.
export default class extends Controller {
  static values = {
    url: String // endpoint for persisting the new order
  }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      ghostClass: "sortable-ghost",
      chosenClass: "sortable-chosen",
      dragClass: "sortable-drag",
      handle: "[data-sortable-handle]",
      draggable: "[data-sortable-item]",
      onEnd: this.onEnd.bind(this)
    })
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
      this.sortable = null
    }
  }

  onEnd(event) {
    // Only persist if the position actually changed
    if (event.oldIndex === event.newIndex) return

    const items = this.element.querySelectorAll("[data-sortable-item]")
    const orderedIds = Array.from(items).map(item => item.dataset.sortableItemId)

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: JSON.stringify({ ordered_ids: orderedIds })
    }).then(response => {
      if (!response.ok) {
        // Revert the DOM on failure by reloading the tree via Turbo
        console.error("Reorder failed:", response.statusText)
      }
    }).catch(error => {
      console.error("Reorder error:", error)
    })
  }
}
