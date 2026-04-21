import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static MAX_ATTEMPTS = 300

  static values = {
    enabled: Boolean,
    sourceId: String,
    inProgress: Boolean,
  }

  connect() {
    if (!this.enabledValue || !this.sourceIdValue) return

    const attempts = Number(window.sessionStorage.getItem(this.counterKey()) || "0")
    if (attempts >= this.maxAttempts()) {
      this.clearCounter()
      return this.refreshWithoutSyncParams()
    }

    const delay = this.inProgressValue ? 2000 : 300
    this.schedulePoll(delay)
  }

  disconnect() {
    if (!this.timer) return

    window.clearTimeout(this.timer)
    this.timer = null
  }

  async pollStatus() {
    this.incrementCounter()

    try {
      const url = `/admin/fx/ingestions.json?source_id=${encodeURIComponent(this.sourceIdValue)}`
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
      })

      if (!response.ok) return this.refreshWithCurrentUrl()

      const payload = await response.json()
      const status = payload?.sources?.[0]?.status

      if (status === "pending" || status === "running") {
        this.inProgressValue = true
        this.schedulePoll(2000)
        return
      }

      this.clearCounter()
      this.refreshWithoutSyncParams()
    } catch (_error) {
      this.schedulePoll(3000)
    }
  }

  schedulePoll(delayMs) {
    if (this.timer) window.clearTimeout(this.timer)
    this.timer = window.setTimeout(() => this.pollStatus(), delayMs)
  }

  refreshWithoutSyncParams() {
    const url = new URL(window.location.href)
    url.searchParams.delete("sync_source_id")
    url.searchParams.delete("market")
    url.searchParams.delete("sync_poll")

    if (window.Turbo && typeof window.Turbo.visit === "function") {
      window.Turbo.visit(url.toString(), { action: "replace" })
      return
    }

    window.location.assign(url.toString())
  }

  incrementCounter() {
    const attempts = Number(window.sessionStorage.getItem(this.counterKey()) || "0") + 1
    window.sessionStorage.setItem(this.counterKey(), String(attempts))
  }

  clearCounter() {
    window.sessionStorage.removeItem(this.counterKey())
  }

  counterKey() {
    return `fx-sync-poll:${this.sourceIdValue}`
  }

  maxAttempts() {
    return this.constructor.MAX_ATTEMPTS
  }
}
