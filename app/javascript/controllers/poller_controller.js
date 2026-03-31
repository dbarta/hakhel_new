import { Controller } from "@hotwired/stimulus"

// Polls the current page on an interval while active=true.
// Stops automatically when active becomes false (e.g. import finished).
export default class extends Controller {
  static values = { active: Boolean, interval: { type: Number, default: 3000 } }

  connect() {
    if (this.activeValue) {
      this.timer = setInterval(() => {
        Turbo.visit(window.location, { action: "replace" })
      }, this.intervalValue)
    }
  }

  disconnect() {
    clearInterval(this.timer)
  }
}
