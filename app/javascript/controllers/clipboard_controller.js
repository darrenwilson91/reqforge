import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

  copy() {
    const text = this.sourceTarget.value || this.sourceTarget.textContent
    navigator.clipboard.writeText(text).then(() => {
      this.showFeedback()
    })
  }

  showFeedback() {
    if (!this.hasButtonTarget) return

    // Store original children
    const originalChildren = Array.from(this.buttonTarget.childNodes).map(n => n.cloneNode(true))

    const span = document.createElement("span")
    span.className = "flex items-center gap-1"

    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    svg.setAttribute("class", "w-4 h-4")
    svg.setAttribute("viewBox", "0 0 20 20")
    svg.setAttribute("fill", "currentColor")
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
    path.setAttribute("fill-rule", "evenodd")
    path.setAttribute("d", "M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z")
    path.setAttribute("clip-rule", "evenodd")
    svg.appendChild(path)

    span.appendChild(svg)
    span.appendChild(document.createTextNode("Copied!"))

    this.buttonTarget.replaceChildren(span)
    this.buttonTarget.classList.add("text-emerald-600")

    setTimeout(() => {
      this.buttonTarget.replaceChildren(...originalChildren)
      this.buttonTarget.classList.remove("text-emerald-600")
    }, 2000)
  }
}
