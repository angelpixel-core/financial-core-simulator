import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    enabled: Boolean,
    sourceId: String,
    inProgress: Boolean,
  }

  connect() {
    if (!this.enabledValue || !this.sourceIdValue) return

    const attempts = Number(window.sessionStorage.getItem(this.counterKey()) || "0")
    if (attempts >= 25) return

    const delay = this.inProgressValue ? 2000 : 300
    this.timer = window.setTimeout(() => this.pollStatus(), delay)
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
        return this.refreshWithCurrentUrl()
      }

      this.clearCounter()
      this.refreshWithoutSyncParams()
    } catch (_error) {
      this.refreshWithCurrentUrl()
    }
  }

  refreshWithCurrentUrl() {
    if (window.Turbo && typeof window.Turbo.visit === "function") {
      window.Turbo.visit(window.location.href, { action: "replace" })
      return
    }

    window.location.reload()
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
}
