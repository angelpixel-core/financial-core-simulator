import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    processing: Boolean,
    uploadId: String,
  }

  connect() {
    if (!this.processingValue) {
      this.resetCounter()
      return
    }

    if (!this.uploadIdValue) return

    const key = this.counterKey()
    const attempts = Number(window.sessionStorage.getItem(key) || "0")
    if (attempts >= 20) return

    window.sessionStorage.setItem(key, String(attempts + 1))

    this.timer = window.setTimeout(() => {
      if (window.Turbo && typeof window.Turbo.visit === "function") {
        window.Turbo.visit(window.location.href, { action: "replace" })
        return
      }

      window.location.reload()
    }, 2000)
  }

  disconnect() {
    if (this.timer) {
      window.clearTimeout(this.timer)
      this.timer = null
    }
  }

  counterKey() {
    return `fx-upload-poll:${this.uploadIdValue}`
  }

  resetCounter() {
    if (!this.uploadIdValue) return

    window.sessionStorage.removeItem(this.counterKey())
  }
}
