import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "toggle"]

  toggle() {
    if (this.panelTarget.hidden) {
      this.open()
      return
    }

    this.close()
  }

  open() {
    this.panelTarget.hidden = false
    this.toggleTarget.setAttribute("aria-expanded", "true")
    requestAnimationFrame(() => this.panelTarget.classList.add("is-open"))
  }

  close() {
    this.panelTarget.classList.remove("is-open")
    this.toggleTarget.setAttribute("aria-expanded", "false")
    window.setTimeout(() => {
      this.panelTarget.hidden = true
    }, 180)
  }
}
