import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle"]

  static values = {
    storageKey: { type: String, default: "admin.shell.sidebar.collapsed" },
    collapsedClass: { type: String, default: "app-shell--sidebar-collapsed" }
  }

  connect() {
    this.collapsed = this.readState()
    this.syncState()
  }

  toggle() {
    this.collapsed = !this.collapsed
    this.persistState(this.collapsed)
    this.syncState()
  }

  expand() {
    if (!this.collapsed) return

    this.collapsed = false
    this.persistState(false)
    this.syncState()
  }

  syncState() {
    this.element.classList.toggle(this.collapsedClassValue, this.collapsed)
    if (!this.hasToggleTarget) return

    this.toggleTarget.setAttribute("aria-pressed", this.collapsed ? "true" : "false")
    this.toggleTarget.setAttribute(
      "aria-label",
      this.collapsed ? "Expandir sidebar" : "Minimizar sidebar"
    )
    this.toggleTarget.setAttribute(
      "title",
      this.collapsed ? "Expandir sidebar" : "Minimizar sidebar"
    )
  }

  readState() {
    try {
      if (!window.localStorage) return false
      return window.localStorage.getItem(this.storageKeyValue) === "1"
    } catch {
      return false
    }
  }

  persistState(collapsed) {
    try {
      if (!window.localStorage) return
      window.localStorage.setItem(this.storageKeyValue, collapsed ? "1" : "0")
    } catch {
      // Ignore storage failures (private mode, disabled storage).
    }
  }
}
