import { Controller } from "@hotwired/stimulus"

// Swiss needs a number of rounds; a round robin may leave it blank (one full cycle). Shows the matching hint.
export default class extends Controller {
  static targets = [ "rounds", "hint" ]
  static values = { system: String }

  connect() {
    this.update()
  }

  toggle(event) {
    this.systemValue = event.target.value
    this.update()
  }

  update() {
    this.hintTargets.forEach(hint => hint.hidden = hint.dataset.system !== this.systemValue)
    if (this.hasRoundsTarget) this.roundsTarget.required = this.systemValue === "swiss"
  }
}
