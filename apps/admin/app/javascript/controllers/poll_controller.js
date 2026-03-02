import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]
  static values = {
    url: String,
    interval: { type: Number, default: 10000 }
  }

  connect() {
    this.refresh()
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async refresh() {
    if (!this.hasContainerTarget || !this.urlValue) return

    const response = await fetch(this.urlValue, {
      headers: { "X-Requested-With": "XMLHttpRequest" }
    })
    if (!response.ok) return

    this.containerTarget.innerHTML = await response.text()
  }
}
