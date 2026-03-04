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
    this.filterTimer = null
  }

  disconnect() {
    clearInterval(this.timer)
    this.clearScheduledFilters()
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
    if (event) event.preventDefault()
    this.clearScheduledFilters()

    const form = this.resolveForm(event)
    if (!form) return

    const nextUrl = this.buildUrlWithQuery(form.action, new FormData(form))
    this.urlValue = nextUrl
    this.refresh()
  }

  scheduleFilters(event) {
    const form = this.resolveForm(event)
    if (!form) return

    this.clearScheduledFilters()
    this.filterTimer = setTimeout(() => this.applyFiltersFromForm(form), 450)
  }

  resetFilters(event) {
    event.preventDefault()

    const form = event.currentTarget.form
    if (!form) return

    form.reset()
    this.urlValue = form.action
    this.refresh()
  }

  applyFiltersFromForm(form) {
    const nextUrl = this.buildUrlWithQuery(form.action, new FormData(form))
    this.urlValue = nextUrl
    this.refresh()
  }

  resolveForm(event) {
    if (!event) return null

    if (event.target instanceof HTMLFormElement) return event.target
    if (event.target?.form) return event.target.form
    if (event.currentTarget?.form) return event.currentTarget.form

    return null
  }

  clearScheduledFilters() {
    if (!this.filterTimer) return

    clearTimeout(this.filterTimer)
    this.filterTimer = null
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
