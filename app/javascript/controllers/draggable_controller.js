import { Controller } from "@hotwired/stimulus"

// Attach to the element you want to make draggable.
// Put data-action="mousedown->draggable#dragStart" on the drag handle inside it.
export default class extends Controller {
  connect() {
    this.dragging  = false
    this.onMove    = this.onMouseMove.bind(this)
    this.onUp      = this.onMouseUp.bind(this)
  }

  dragStart(event) {
    // Snapshot rendered position first (before clearing transform)
    const rect = this.element.getBoundingClientRect()
    // Clear transform and right (RTL sets right automatically, which fights left)
    this.element.style.transform = "none"
    this.element.style.margin    = "0"
    this.element.style.position  = "fixed"
    this.element.style.right     = "auto"
    this.element.style.left      = rect.left + "px"
    this.element.style.top       = rect.top  + "px"

    this.dragging  = true
    this.originX   = event.clientX
    this.originY   = event.clientY
    this.startLeft = rect.left
    this.startTop  = rect.top

    document.addEventListener("mousemove", this.onMove)
    document.addEventListener("mouseup",   this.onUp)
    event.preventDefault()
  }

  onMouseMove(event) {
    if (!this.dragging) return
    this.element.style.left = (this.startLeft + event.clientX - this.originX) + "px"
    this.element.style.top  = (this.startTop  + event.clientY - this.originY) + "px"
  }

  onMouseUp() {
    this.dragging = false
    document.removeEventListener("mousemove", this.onMove)
    document.removeEventListener("mouseup",   this.onUp)
  }

  disconnect() {
    document.removeEventListener("mousemove", this.onMove)
    document.removeEventListener("mouseup",   this.onUp)
  }
}
