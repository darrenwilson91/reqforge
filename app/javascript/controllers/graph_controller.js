import { Controller } from "@hotwired/stimulus"

// Force-directed graph layout for traceability visualization
export default class extends Controller {
  static targets = ["canvas", "tooltip", "zoomLevel"]
  static values = {
    nodes: { type: Array, default: [] },
    edges: { type: Array, default: [] }
  }

  // Layout constants
  static REPULSION = 8000
  static ATTRACTION = 0.005
  static DAMPING = 0.85
  static MIN_DISTANCE = 80
  static ITERATIONS = 200
  static NODE_RADIUS = 24
  static ARROW_SIZE = 8

  // Module color palette — distinct, accessible colors
  static MODULE_COLORS = [
    { fill: "#eff6ff", stroke: "#3b82f6", text: "#1e40af" },  // blue
    { fill: "#f0fdf4", stroke: "#22c55e", text: "#166534" },  // green
    { fill: "#faf5ff", stroke: "#a855f7", text: "#7e22ce" },  // purple
    { fill: "#fff7ed", stroke: "#f97316", text: "#c2410c" },  // orange
    { fill: "#fdf2f8", stroke: "#ec4899", text: "#be185d" },  // pink
    { fill: "#f0fdfa", stroke: "#14b8a6", text: "#0f766e" },  // teal
    { fill: "#fefce8", stroke: "#eab308", text: "#a16207" },  // yellow
    { fill: "#fef2f2", stroke: "#ef4444", text: "#b91c1c" },  // red
  ]

  static LINK_TYPE_COLORS = {
    derives_from: "#3b82f6",
    satisfies: "#22c55e",
    verifies: "#8b5cf6",
    conflicts_with: "#ef4444",
    refines: "#f59e0b",
    implements: "#14b8a6",
    parent_child: "#94a3b8"
  }

  connect() {
    this.nodes = []
    this.edges = []
    this.transform = { x: 0, y: 0, scale: 1 }
    this.dragging = null
    this.panning = false
    this.panStart = { x: 0, y: 0 }
    this.selectedNode = null

    this.parseGraphData()

    if (this.nodes.length === 0) return

    this.computeLayout()
    this.render()
    this.bindEvents()
  }

  disconnect() {
    this.unbindEvents()
  }

  parseGraphData() {
    const nodesData = this.nodesValue
    const edgesData = this.edgesValue

    // Assign module colors
    const moduleIds = [...new Set(nodesData.map(n => n.module_id))].filter(Boolean)
    const moduleColorMap = {}
    moduleIds.forEach((id, i) => {
      moduleColorMap[id] = this.constructor.MODULE_COLORS[i % this.constructor.MODULE_COLORS.length]
    })

    this.nodes = nodesData.map(n => ({
      id: n.id,
      uid: n.uid,
      title: n.title,
      module_id: n.module_id,
      module_name: n.module_name || "",
      status: n.status,
      url: n.url,
      color: moduleColorMap[n.module_id] || this.constructor.MODULE_COLORS[0],
      x: 0,
      y: 0,
      vx: 0,
      vy: 0,
      fx: null,
      fy: null
    }))

    this.nodeMap = {}
    this.nodes.forEach(n => { this.nodeMap[n.id] = n })

    this.edges = edgesData
      .filter(e => this.nodeMap[e.source_id] && this.nodeMap[e.target_id])
      .map(e => ({
        source: this.nodeMap[e.source_id],
        target: this.nodeMap[e.target_id],
        link_type: e.link_type,
        color: this.constructor.LINK_TYPE_COLORS[e.link_type] || "#94a3b8"
      }))
  }

  computeLayout() {
    const width = this.canvasTarget.clientWidth || 900
    const height = this.canvasTarget.clientHeight || 600
    const cx = width / 2
    const cy = height / 2

    // Initial positions: arrange in a circle by module, with some randomness
    const moduleGroups = {}
    this.nodes.forEach(n => {
      const key = n.module_id || "none"
      if (!moduleGroups[key]) moduleGroups[key] = []
      moduleGroups[key].push(n)
    })

    const groupKeys = Object.keys(moduleGroups)
    groupKeys.forEach((key, gi) => {
      const group = moduleGroups[key]
      const groupAngle = (2 * Math.PI * gi) / groupKeys.length
      const groupCx = cx + Math.cos(groupAngle) * Math.min(width, height) * 0.25
      const groupCy = cy + Math.sin(groupAngle) * Math.min(width, height) * 0.25

      group.forEach((n, ni) => {
        const angle = (2 * Math.PI * ni) / group.length
        const r = 30 + group.length * 8
        n.x = groupCx + Math.cos(angle) * r + (Math.random() - 0.5) * 20
        n.y = groupCy + Math.sin(angle) * r + (Math.random() - 0.5) * 20
      })
    })

    // Force simulation
    const REPULSION = this.constructor.REPULSION
    const ATTRACTION = this.constructor.ATTRACTION
    const DAMPING = this.constructor.DAMPING
    const MIN_DISTANCE = this.constructor.MIN_DISTANCE
    const iterations = this.constructor.ITERATIONS

    for (let iter = 0; iter < iterations; iter++) {
      const alpha = 1 - iter / iterations

      // Repulsion between all node pairs
      for (let i = 0; i < this.nodes.length; i++) {
        for (let j = i + 1; j < this.nodes.length; j++) {
          const a = this.nodes[i]
          const b = this.nodes[j]
          let dx = b.x - a.x
          let dy = b.y - a.y
          let dist = Math.sqrt(dx * dx + dy * dy)
          if (dist < 1) { dist = 1; dx = Math.random() - 0.5; dy = Math.random() - 0.5 }

          const force = REPULSION / (dist * dist)
          const fx = (dx / dist) * force * alpha
          const fy = (dy / dist) * force * alpha

          a.vx -= fx
          a.vy -= fy
          b.vx += fx
          b.vy += fy
        }
      }

      // Attraction along edges
      for (const edge of this.edges) {
        const dx = edge.target.x - edge.source.x
        const dy = edge.target.y - edge.source.y
        const dist = Math.sqrt(dx * dx + dy * dy)
        if (dist < 1) continue

        const force = dist * ATTRACTION * alpha
        const fx = (dx / dist) * force
        const fy = (dy / dist) * force

        edge.source.vx += fx
        edge.source.vy += fy
        edge.target.vx -= fx
        edge.target.vy -= fy
      }

      // Minimum distance enforcement
      for (let i = 0; i < this.nodes.length; i++) {
        for (let j = i + 1; j < this.nodes.length; j++) {
          const a = this.nodes[i]
          const b = this.nodes[j]
          const dx = b.x - a.x
          const dy = b.y - a.y
          const dist = Math.sqrt(dx * dx + dy * dy)
          if (dist < MIN_DISTANCE && dist > 0) {
            const overlap = (MIN_DISTANCE - dist) / 2
            const nx = dx / dist
            const ny = dy / dist
            a.x -= nx * overlap * alpha
            a.y -= ny * overlap * alpha
            b.x += nx * overlap * alpha
            b.y += ny * overlap * alpha
          }
        }
      }

      // Centering force
      let avgX = 0, avgY = 0
      this.nodes.forEach(n => { avgX += n.x; avgY += n.y })
      avgX /= this.nodes.length
      avgY /= this.nodes.length
      this.nodes.forEach(n => {
        n.x -= (avgX - cx) * 0.1 * alpha
        n.y -= (avgY - cy) * 0.1 * alpha
      })

      // Apply velocity and damping
      this.nodes.forEach(n => {
        if (n.fx !== null) { n.x = n.fx; n.vx = 0 }
        else { n.x += n.vx; n.vx *= DAMPING }
        if (n.fy !== null) { n.y = n.fy; n.vy = 0 }
        else { n.y += n.vy; n.vy *= DAMPING }
      })
    }

    // Center graph and fit to viewport
    this.fitToView()
  }

  fitToView() {
    if (this.nodes.length === 0) return

    const width = this.canvasTarget.clientWidth || 900
    const height = this.canvasTarget.clientHeight || 600
    const padding = 60

    let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity
    this.nodes.forEach(n => {
      if (n.x < minX) minX = n.x
      if (n.x > maxX) maxX = n.x
      if (n.y < minY) minY = n.y
      if (n.y > maxY) maxY = n.y
    })

    const graphWidth = maxX - minX + padding * 2
    const graphHeight = maxY - minY + padding * 2

    const scale = Math.min(
      width / graphWidth,
      height / graphHeight,
      1.5
    )

    this.transform.scale = Math.max(0.2, Math.min(scale, 2))
    this.transform.x = (width / 2) - ((minX + maxX) / 2) * this.transform.scale
    this.transform.y = (height / 2) - ((minY + maxY) / 2) * this.transform.scale

    this.updateZoomDisplay()
  }

  render() {
    const svg = this.canvasTarget
    const NS = "http://www.w3.org/2000/svg"

    // Clear existing content except defs
    while (svg.lastChild) svg.removeChild(svg.lastChild)

    // Defs for arrowheads
    const defs = document.createElementNS(NS, "defs")

    // Create arrow markers for each link type color
    const usedColors = new Set(this.edges.map(e => e.color))
    usedColors.forEach(color => {
      const marker = document.createElementNS(NS, "marker")
      marker.setAttribute("id", `arrow-${color.replace("#", "")}`)
      marker.setAttribute("viewBox", "0 0 10 10")
      marker.setAttribute("refX", "10")
      marker.setAttribute("refY", "5")
      marker.setAttribute("markerWidth", this.constructor.ARROW_SIZE)
      marker.setAttribute("markerHeight", this.constructor.ARROW_SIZE)
      marker.setAttribute("orient", "auto-start-reverse")
      const path = document.createElementNS(NS, "path")
      path.setAttribute("d", "M 0 0 L 10 5 L 0 10 z")
      path.setAttribute("fill", color)
      marker.appendChild(path)
      defs.appendChild(marker)
    })

    svg.appendChild(defs)

    // Main group for pan/zoom
    const g = document.createElementNS(NS, "g")
    g.setAttribute("transform", `translate(${this.transform.x},${this.transform.y}) scale(${this.transform.scale})`)
    this.mainGroup = g

    // Draw edges
    const R = this.constructor.NODE_RADIUS
    this.edges.forEach(edge => {
      const dx = edge.target.x - edge.source.x
      const dy = edge.target.y - edge.source.y
      const dist = Math.sqrt(dx * dx + dy * dy)
      if (dist < 1) return

      // Offset line endpoints to node border
      const nx = dx / dist
      const ny = dy / dist
      const sx = edge.source.x + nx * R
      const sy = edge.source.y + ny * R
      const tx = edge.target.x - nx * (R + this.constructor.ARROW_SIZE)
      const ty = edge.target.y - ny * (R + this.constructor.ARROW_SIZE)

      const line = document.createElementNS(NS, "line")
      line.setAttribute("x1", sx)
      line.setAttribute("y1", sy)
      line.setAttribute("x2", tx)
      line.setAttribute("y2", ty)
      line.setAttribute("stroke", edge.color)
      line.setAttribute("stroke-width", "1.5")
      line.setAttribute("stroke-opacity", "0.6")
      line.setAttribute("marker-end", `url(#arrow-${edge.color.replace("#", "")})`)
      line.dataset.edgeSource = edge.source.id
      line.dataset.edgeTarget = edge.target.id
      line.dataset.linkType = edge.link_type
      g.appendChild(line)
    })

    // Draw nodes
    this.nodes.forEach(node => {
      const group = document.createElementNS(NS, "g")
      group.setAttribute("transform", `translate(${node.x},${node.y})`)
      group.dataset.nodeId = node.id
      group.style.cursor = "grab"

      // Node circle
      const circle = document.createElementNS(NS, "circle")
      circle.setAttribute("r", R)
      circle.setAttribute("fill", node.color.fill)
      circle.setAttribute("stroke", node.color.stroke)
      circle.setAttribute("stroke-width", "2")
      group.appendChild(circle)

      // UID text
      const text = document.createElementNS(NS, "text")
      text.setAttribute("text-anchor", "middle")
      text.setAttribute("dominant-baseline", "central")
      text.setAttribute("fill", node.color.text)
      text.setAttribute("font-size", "9")
      text.setAttribute("font-weight", "600")
      text.setAttribute("font-family", "'JetBrains Mono', monospace")
      text.setAttribute("pointer-events", "none")
      text.textContent = node.uid.length > 8 ? node.uid.slice(-6) : node.uid
      group.appendChild(text)

      g.appendChild(group)
    })

    svg.appendChild(g)
  }

  updateTransform() {
    if (this.mainGroup) {
      this.mainGroup.setAttribute(
        "transform",
        `translate(${this.transform.x},${this.transform.y}) scale(${this.transform.scale})`
      )
    }
    this.updateZoomDisplay()
  }

  updateZoomDisplay() {
    if (this.hasZoomLevelTarget) {
      this.zoomLevelTarget.textContent = `${Math.round(this.transform.scale * 100)}%`
    }
  }

  // --- Events ---

  bindEvents() {
    const svg = this.canvasTarget

    this._onMouseDown = this.onMouseDown.bind(this)
    this._onMouseMove = this.onMouseMove.bind(this)
    this._onMouseUp = this.onMouseUp.bind(this)
    this._onWheel = this.onWheel.bind(this)

    svg.addEventListener("mousedown", this._onMouseDown)
    svg.addEventListener("mousemove", this._onMouseMove)
    svg.addEventListener("mouseup", this._onMouseUp)
    svg.addEventListener("mouseleave", this._onMouseUp)
    svg.addEventListener("wheel", this._onWheel, { passive: false })
  }

  unbindEvents() {
    const svg = this.canvasTarget
    if (this._onMouseDown) svg.removeEventListener("mousedown", this._onMouseDown)
    if (this._onMouseMove) svg.removeEventListener("mousemove", this._onMouseMove)
    if (this._onMouseUp) svg.removeEventListener("mouseup", this._onMouseUp)
    if (this._onWheel) svg.removeEventListener("wheel", this._onWheel)
  }

  screenToGraph(sx, sy) {
    return {
      x: (sx - this.transform.x) / this.transform.scale,
      y: (sy - this.transform.y) / this.transform.scale
    }
  }

  findNodeAt(gx, gy) {
    const R = this.constructor.NODE_RADIUS
    for (let i = this.nodes.length - 1; i >= 0; i--) {
      const n = this.nodes[i]
      const dx = gx - n.x
      const dy = gy - n.y
      if (dx * dx + dy * dy <= R * R) return n
    }
    return null
  }

  onMouseDown(e) {
    const rect = this.canvasTarget.getBoundingClientRect()
    const sx = e.clientX - rect.left
    const sy = e.clientY - rect.top
    const gp = this.screenToGraph(sx, sy)

    const node = this.findNodeAt(gp.x, gp.y)
    if (node) {
      this.dragging = node
      this.dragOffset = { x: gp.x - node.x, y: gp.y - node.y }
      this.canvasTarget.style.cursor = "grabbing"
      this.highlightNode(node)
      e.preventDefault()
    } else {
      this.panning = true
      this.panStart = { x: e.clientX - this.transform.x, y: e.clientY - this.transform.y }
      this.canvasTarget.style.cursor = "move"
      e.preventDefault()
    }
  }

  onMouseMove(e) {
    const rect = this.canvasTarget.getBoundingClientRect()
    const sx = e.clientX - rect.left
    const sy = e.clientY - rect.top

    if (this.dragging) {
      const gp = this.screenToGraph(sx, sy)
      this.dragging.x = gp.x - this.dragOffset.x
      this.dragging.y = gp.y - this.dragOffset.y
      this.render()
      this.highlightNode(this.dragging)
      return
    }

    if (this.panning) {
      this.transform.x = e.clientX - this.panStart.x
      this.transform.y = e.clientY - this.panStart.y
      this.updateTransform()
      return
    }

    // Hover tooltip
    const gp = this.screenToGraph(sx, sy)
    const node = this.findNodeAt(gp.x, gp.y)
    if (node) {
      this.showTooltip(node, e.clientX, e.clientY)
      this.canvasTarget.style.cursor = "grab"
    } else {
      this.hideTooltip()
      this.canvasTarget.style.cursor = "default"
    }
  }

  onMouseUp(e) {
    if (this.dragging) {
      // If barely moved, treat as click — navigate to requirement
      this.dragging = null
      this.canvasTarget.style.cursor = "default"
    }
    if (this.panning) {
      this.panning = false
      this.canvasTarget.style.cursor = "default"
    }
  }

  onWheel(e) {
    e.preventDefault()
    const rect = this.canvasTarget.getBoundingClientRect()
    const mx = e.clientX - rect.left
    const my = e.clientY - rect.top

    const delta = e.deltaY > 0 ? 0.9 : 1.1
    const newScale = Math.max(0.15, Math.min(this.transform.scale * delta, 4))

    // Zoom towards mouse position
    this.transform.x = mx - (mx - this.transform.x) * (newScale / this.transform.scale)
    this.transform.y = my - (my - this.transform.y) * (newScale / this.transform.scale)
    this.transform.scale = newScale

    this.updateTransform()
  }

  // --- Highlight ---

  highlightNode(node) {
    const svg = this.canvasTarget
    // Reset all opacity
    svg.querySelectorAll("[data-node-id]").forEach(g => {
      g.style.opacity = "0.3"
    })
    svg.querySelectorAll("[data-edge-source]").forEach(line => {
      line.style.opacity = "0.1"
    })

    // Highlight connected nodes and edges
    const connectedIds = new Set([node.id])
    svg.querySelectorAll("[data-edge-source]").forEach(line => {
      const src = parseInt(line.dataset.edgeSource)
      const tgt = parseInt(line.dataset.edgeTarget)
      if (src === node.id || tgt === node.id) {
        line.style.opacity = "1"
        line.setAttribute("stroke-width", "2.5")
        connectedIds.add(src)
        connectedIds.add(tgt)
      }
    })

    svg.querySelectorAll("[data-node-id]").forEach(g => {
      if (connectedIds.has(parseInt(g.dataset.nodeId))) {
        g.style.opacity = "1"
      }
    })
  }

  resetHighlight() {
    const svg = this.canvasTarget
    svg.querySelectorAll("[data-node-id]").forEach(g => {
      g.style.opacity = "1"
    })
    svg.querySelectorAll("[data-edge-source]").forEach(line => {
      line.style.opacity = "1"
      line.setAttribute("stroke-width", "1.5")
      line.setAttribute("stroke-opacity", "0.6")
    })
  }

  // --- Tooltip ---

  showTooltip(node, cx, cy) {
    if (!this.hasTooltipTarget) return

    const tip = this.tooltipTarget
    const linkCount = this.edges.filter(
      e => e.source.id === node.id || e.target.id === node.id
    ).length

    // Build tooltip content safely
    while (tip.firstChild) tip.removeChild(tip.firstChild)

    const uidEl = document.createElement("div")
    uidEl.className = "rf-uid text-xs"
    uidEl.textContent = node.uid
    tip.appendChild(uidEl)

    const titleEl = document.createElement("div")
    titleEl.className = "text-sm font-medium text-slate-900 mt-1 max-w-[200px] truncate"
    titleEl.textContent = node.title
    tip.appendChild(titleEl)

    if (node.module_name) {
      const modEl = document.createElement("div")
      modEl.className = "text-xs text-slate-500 mt-0.5"
      modEl.textContent = node.module_name
      tip.appendChild(modEl)
    }

    const metaEl = document.createElement("div")
    metaEl.className = "text-xs text-slate-400 mt-1 flex items-center gap-2"
    const statusSpan = document.createElement("span")
    statusSpan.textContent = node.status.replace(/_/g, " ")
    metaEl.appendChild(statusSpan)
    const sep = document.createElement("span")
    sep.textContent = "\u00b7"
    metaEl.appendChild(sep)
    const linkSpan = document.createElement("span")
    linkSpan.textContent = `${linkCount} link${linkCount !== 1 ? "s" : ""}`
    metaEl.appendChild(linkSpan)
    tip.appendChild(metaEl)

    tip.classList.remove("hidden")

    // Position near cursor
    const rect = this.canvasTarget.getBoundingClientRect()
    tip.style.left = `${cx - rect.left + 12}px`
    tip.style.top = `${cy - rect.top - 10}px`
  }

  hideTooltip() {
    if (this.hasTooltipTarget) {
      this.tooltipTarget.classList.add("hidden")
    }
  }

  // --- Toolbar actions ---

  zoomIn() {
    const cx = this.canvasTarget.clientWidth / 2
    const cy = this.canvasTarget.clientHeight / 2
    const newScale = Math.min(this.transform.scale * 1.25, 4)
    this.transform.x = cx - (cx - this.transform.x) * (newScale / this.transform.scale)
    this.transform.y = cy - (cy - this.transform.y) * (newScale / this.transform.scale)
    this.transform.scale = newScale
    this.updateTransform()
  }

  zoomOut() {
    const cx = this.canvasTarget.clientWidth / 2
    const cy = this.canvasTarget.clientHeight / 2
    const newScale = Math.max(this.transform.scale * 0.8, 0.15)
    this.transform.x = cx - (cx - this.transform.x) * (newScale / this.transform.scale)
    this.transform.y = cy - (cy - this.transform.y) * (newScale / this.transform.scale)
    this.transform.scale = newScale
    this.updateTransform()
  }

  resetView() {
    this.fitToView()
    this.updateTransform()
    this.resetHighlight()
  }

  navigateToNode(e) {
    const nodeId = e.currentTarget.dataset.nodeId
    const node = this.nodeMap[parseInt(nodeId)]
    if (node && node.url) {
      window.location.href = node.url
    }
  }
}
