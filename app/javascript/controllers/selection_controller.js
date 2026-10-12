import { Controller } from "@hotwired/stimulus"

// Keeps the submit button in sync with the checked checkboxes.
export default class extends Controller {
  static targets = [ "checkbox", "submit" ]

  connect() {
    this.update()
  }

  toggleVisible() {
    const visible = this.checkboxTargets.filter(checkbox => !checkbox.closest("[hidden]"))
    const check = visible.some(checkbox => !checkbox.checked)
    visible.forEach(checkbox => checkbox.checked = check)
    this.update()
  }

  update() {
    const count = this.checkboxTargets.filter(checkbox => checkbox.checked).length
    this.submitTarget.disabled = count === 0
    this.submitTarget.textContent = count > 1 ? `Add ${count} players` : count === 1 ? "Add 1 player" : "Add selected"
  }
}
