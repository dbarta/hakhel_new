import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open(event) {
    event.preventDefault()
    this.element.classList.remove("hidden")
    this.element.classList.add("flex")
  }

  close() {
    this.element.classList.add("hidden")
    this.element.classList.remove("flex")
    // Clear the turbo frame so it reloads fresh next time
    const frame = this.element.querySelector("turbo-frame")
    if (frame) frame.innerHTML = ""
  }

  backdropClose(event) {
    // Close when clicking the backdrop (the outer div), not the inner card
    if (event.target === event.currentTarget) this.close()
  }
}
