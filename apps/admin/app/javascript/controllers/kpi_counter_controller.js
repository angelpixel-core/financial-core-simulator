import { Controller } from "@hotwired/stimulus"

const REDUCED_MOTION_QUERY = "(prefers-reduced-motion: reduce)"

export default class extends Controller {
  static targets = ["value"]
  static values = {
    final: Number,
    kind: { type: String, default: "integer" },
    precision: { type: Number, default: 0 },
    duration: { type: Number, default: 700 }
  }

  connect() {
    if (!this.hasValueTarget || !this.hasFinalValue) return

    if (this.prefersReducedMotion() || this.durationValue <= 0) {
      this.renderValue(this.finalValue)
      return
    }

    this.startTime = performance.now()
    this.frame = requestAnimationFrame((timestamp) => this.animate(timestamp))
  }

  disconnect() {
    if (!this.frame) return

    cancelAnimationFrame(this.frame)
    this.frame = null
  }

  animate(timestamp) {
    const elapsed = timestamp - this.startTime
    const progress = Math.min(elapsed / this.durationValue, 1)
    const easedProgress = 1 - Math.pow(1 - progress, 3)
    const nextValue = this.finalValue * easedProgress
    this.renderValue(nextValue)

    if (progress < 1) {
      this.frame = requestAnimationFrame((nextTimestamp) => this.animate(nextTimestamp))
      return
    }

    this.renderValue(this.finalValue)
    this.frame = null
  }

  renderValue(rawValue) {
    this.valueTarget.textContent = this.formatValue(rawValue)
  }

  formatValue(rawValue) {
    const precision = Math.max(0, this.precisionValue)
    const value = Number.isFinite(rawValue) ? rawValue : 0

    if (this.kindValue === "percent") {
      return `${value.toFixed(precision)}%`
    }

    if (this.kindValue === "milliseconds") {
      return `${value.toFixed(precision)} ms`
    }

    return value.toFixed(precision)
  }

  prefersReducedMotion() {
    return window.matchMedia(REDUCED_MOTION_QUERY).matches
  }
}
