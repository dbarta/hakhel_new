import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { impactUrl: String }

  connect() {
    console.log("pref-confirm connected")
  }

  submit(event) {
    console.log("pref-confirm submit intercepted")
    event.preventDefault()

    if (!this.hasImpactUrlValue) {
      console.log("no impact url — normal submit")
      this.element.submit()
      return
    }

    const formData = new FormData(this.element)
    const token = document.querySelector('meta[name="csrf-token"]')?.content

	    fetch(this.impactUrlValue, {
	      method: "PATCH",
      headers: {
        "X-CSRF-Token": token,
        "Accept": "application/json"
      },
      body: formData
    })
	      .then(r => {
	        if (!r.ok) throw new Error(`impact preview HTTP ${r.status}`)
	        return r.json()
	      })
      .then(data => {
        console.log("impact preview:", data)

	        const count = data.impact_count || 0

        if (count === 0) {
          this.element.submit()
          return
        }

        if (confirm(`השינוי ישפיע על ${count} הודעות עתידיות. להמשיך?`)) {
          this.element.submit()
        }
      })
      .catch(e => {
        console.error("impact preview failed", e)
        this.element.submit()
      })
  }
}
