import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Reloads the new-crawl form for the chosen domain, so defaults and limits match it.
export default class extends Controller {
  static values = { url: String }

  visit() {
    Turbo.visit(`${this.urlValue}?domain_id=${encodeURIComponent(this.element.value)}`)
  }
}
