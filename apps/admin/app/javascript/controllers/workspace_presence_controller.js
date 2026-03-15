import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.retryTimer = null
    this.isHover = false
    this.connectSocket()
  }

  disconnect() {
    this.clearRetry()
    this.closeSocket()
  }

  enter() {
    this.isHover = true
    this.element.classList.add("is-hovered")
  }

  leave() {
    this.isHover = false
    this.element.classList.remove("is-hovered")
  }

  connectSocket() {
    if (!window.WebSocket) return

    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:"
    const url = `${protocol}//${window.location.host}/cable`

    try {
      this.socket = new WebSocket(url)
    } catch {
      this.scheduleReconnect()
      return
    }

    this.socket.addEventListener("open", () => {
      this.element.dataset.presenceState = "connected"
      this.clearRetry()
    })

    this.socket.addEventListener("close", () => {
      this.element.dataset.presenceState = "disconnected"
      this.scheduleReconnect()
    })

    this.socket.addEventListener("error", () => {
      this.element.dataset.presenceState = "disconnected"
      this.closeSocket()
      this.scheduleReconnect()
    })
  }

  scheduleReconnect() {
    if (this.retryTimer) return

    this.retryTimer = window.setTimeout(() => {
      this.retryTimer = null
      this.connectSocket()
    }, 5000)
  }

  closeSocket() {
    if (!this.socket) return

    this.socket.onclose = null
    this.socket.close()
    this.socket = null
  }

  clearRetry() {
    if (!this.retryTimer) return

    window.clearTimeout(this.retryTimer)
    this.retryTimer = null
  }
}
