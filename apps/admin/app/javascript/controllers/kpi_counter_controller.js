import { Controller } from "@hotwired/stimulus"

const REDUCED_MOTION_QUERY = "(prefers-reduced-motion: reduce)"

export default class extends Controller {
  static targets = ["value"]
  static values = {
    final: Number,
    kind: { type: String, default: "integer" },
    precision: { type: Number, default: 0 },
    duration: Number
  }

  connect() {
    if (!this.hasValueTarget || !this.hasFinalValue) return

    this.durationMs = this.resolveDurationMs()
    this.easing = this.resolveEasingName()

    if (this.prefersReducedMotion() || this.durationMs <= 0) {
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
    const progress = Math.min(elapsed / this.durationMs, 1)
    const easedProgress = this.easingProgress(progress)
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

  resolveDurationMs() {
    if (this.hasDurationValue) return this.durationValue

    const cssValue = this.readMotionToken("--motion-kpi-counter-duration-ms")
    const parsed = Number.parseFloat(cssValue)
    return Number.isFinite(parsed) ? parsed : 700
  }

  resolveEasingName() {
    const cssValue = this.readMotionToken("--motion-kpi-counter-ease")
    if (!cssValue) return "cubic"

    return cssValue.includes("linear") ? "linear" : "cubic"
  }

  easingProgress(progress) {
    if (this.easing === "linear") return progress

    return 1 - Math.pow(1 - progress, 3)
  }

  readMotionToken(name) {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim()
  }
}
