import { Controller } from "@hotwired/stimulus"

// Hides list items whose data-filter-text doesn't contain the typed text.
export default class extends Controller {
  static targets = [ "item", "empty" ]

  apply(event) {
    const query = event.target.value.trim().toLowerCase()
    let shown = 0

    this.itemTargets.forEach(item => {
      const match = item.dataset.filterText.includes(query)
      item.hidden = !match
      if (match) shown++
    })

    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown > 0
  }
}
