import { Controller } from "@hotwired/stimulus"

// Shows the "number of rounds" field only for Swiss tournaments (round robins derive it from the members).
export default class extends Controller {
  static targets = [ "system", "rounds" ]

  connect() {
    this.toggle()
  }

  toggle() {
    if (!this.hasRoundsTarget || !this.hasSystemTarget) return

    const swiss = this.systemTargets.find(radio => radio.checked)?.value !== "round_robin"
    this.roundsTarget.hidden = !swiss
    this.roundsTarget.querySelectorAll("input").forEach(input => input.disabled = !swiss)
  }
}
