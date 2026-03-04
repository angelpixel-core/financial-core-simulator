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

  applyFilters(event) {
    event.preventDefault()

    const form = event.target
    const nextUrl = this.buildUrlWithQuery(form.action, new FormData(form))
    this.urlValue = nextUrl
    this.refresh()
  }

  resetFilters(event) {
    event.preventDefault()

    const form = event.currentTarget.form
    if (!form) return

    form.reset()
    this.urlValue = form.action
    this.refresh()
  }

  buildUrlWithQuery(baseUrl, formData) {
    const params = new URLSearchParams()

    for (const [key, value] of formData.entries()) {
      const normalized = String(value).trim()
      if (normalized.length > 0) params.append(key, normalized)
    }

    const query = params.toString()
    return query.length > 0 ? `${baseUrl}?${query}` : baseUrl
  }
}
