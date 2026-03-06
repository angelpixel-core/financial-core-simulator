import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.submitTimer = null
  }

  disconnect() {
    this.clearScheduledSubmit()
  }

  syncPollUrl(event) {
    const form = event?.target || this.element
    if (!(form instanceof HTMLFormElement)) return

    this.setPollUrl(form)
  }

  submitNow(event) {
    const form = this.resolveForm(event)
    if (!form) return

    this.clearScheduledSubmit()
    this.setPollUrl(form)
    form.requestSubmit()
  }

  scheduleSubmit(event) {
    const form = this.resolveForm(event)
    if (!form) return

    this.clearScheduledSubmit()
    this.submitTimer = setTimeout(() => {
      this.setPollUrl(form)
      form.requestSubmit()
    }, 450)
  }

  reset(event) {
    event.preventDefault()

    const form = this.resolveForm(event)
    if (!form) return

    this.clearScheduledSubmit()
    this.clearFilterInputs(form)
    this.setPollUrl(form)
    form.requestSubmit()
  }

  clearFilterInputs(form) {
    this.filterInput(form, "source")
    this.filterInput(form, "field")
  }

  filterInput(form, name) {
    const input = form.elements.namedItem(name)
    if (input instanceof HTMLInputElement) input.value = ""
  }

  resolveForm(event) {
    if (!event) return this.element
    if (event.target instanceof HTMLFormElement) return event.target
    if (event.target?.form) return event.target.form
    if (event.currentTarget?.form) return event.currentTarget.form

    return this.element
  }

  clearScheduledSubmit() {
    if (!this.submitTimer) return

    clearTimeout(this.submitTimer)
    this.submitTimer = null
  }

  setPollUrl(form) {
    const pollElement = form.closest("[data-controller~='poll']")
    if (!pollElement) return

    pollElement.dataset.pollUrlValue = this.buildUrlWithQuery(form.action, new FormData(form))
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
