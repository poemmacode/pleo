import { Controller } from "@hotwired/stimulus"

// Shows the instructions for the verification method selected in the domain card.
export default class extends Controller {
  static targets = ["panel"]

  show(event) {
    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.method !== event.target.value
    })
  }
}
