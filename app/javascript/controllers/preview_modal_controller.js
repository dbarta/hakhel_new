import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]

  open() {
    // Don't prevent default — Turbo needs to follow the link into the frame
    this.overlayTarget.classList.remove("hidden")
  }

  close() {
    this.overlayTarget.classList.add("hidden")
    // Clear the frame so it reloads fresh next time
    const frame = this.overlayTarget.querySelector("turbo-frame")
    if (frame) frame.innerHTML = ""
  }

  backdropClose(event) {
    if (event.target === event.currentTarget) this.close()
  }
}
