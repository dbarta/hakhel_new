import { Controller } from "@hotwired/stimulus"

// Closes a <details> element when clicking outside it or pressing Escape.
// Does not implement any toggle/open behavior.
export default class extends Controller {
  connect() {
    this._onPointerDown = this.onPointerDown.bind(this)
    this._onKeyDown = this.onKeyDown.bind(this)

    document.addEventListener("pointerdown", this._onPointerDown, true)
    document.addEventListener("keydown", this._onKeyDown, true)
  }

  disconnect() {
    document.removeEventListener("pointerdown", this._onPointerDown, true)
    document.removeEventListener("keydown", this._onKeyDown, true)
  }

  onPointerDown(event) {
    if (!this.element.hasAttribute("open")) return
    if (this.element.contains(event.target)) return

    this.element.removeAttribute("open")
  }

  onKeyDown(event) {
    if (event.key !== "Escape") return
    if (!this.element.hasAttribute("open")) return

    this.element.removeAttribute("open")
    this.element.querySelector("summary")?.focus()
  }
}

