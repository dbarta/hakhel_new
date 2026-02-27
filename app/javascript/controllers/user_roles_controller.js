import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["communityAdmin", "communityUser", "communityField"]

  connect() {
    this.toggle()
  }

  toggle() {
    const needsCommunity =
      this.communityAdminTarget.checked || this.communityUserTarget.checked
    this.communityFieldTarget.hidden = !needsCommunity

    // Make the select required only when visible
    const select = this.communityFieldTarget.querySelector("select")
    if (select) {
      select.required = needsCommunity
    }
  }
}

