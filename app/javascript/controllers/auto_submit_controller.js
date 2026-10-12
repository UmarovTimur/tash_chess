import { Controller } from "@hotwired/stimulus"

// Submits the form shortly after the user stops typing.
export default class extends Controller {
  static values = { delay: { type: Number, default: 250 } }

  disconnect() {
    clearTimeout(this.timeout)
  }

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }
}
