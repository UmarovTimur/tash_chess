import { Controller } from "@hotwired/stimulus"

// Fades a flash message out after a few seconds, or right away when clicked.
export default class extends Controller {
  static values = { timeout: { type: Number, default: 5000 } }

  connect() {
    this.timer = setTimeout(() => this.dismiss(), this.timeoutValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  dismiss() {
    this.element.classList.add("flash--leaving")
    setTimeout(() => this.element.remove(), 300)
  }
}
