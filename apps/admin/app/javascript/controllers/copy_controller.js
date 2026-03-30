import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label", "status"]
  static values = {
    text: String,
    defaultLabel: String,
    copiedLabel: String,
    resetDelay: { type: Number, default: 2000 }
  }

  connect() {
    this.resetTimer = null
  }

  disconnect() {
    if (this.resetTimer) {
      clearTimeout(this.resetTimer)
    }
  }

  async copy() {
    if (!this.textValue) {
      return
    }

    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(this.textValue)
      } else {
        this.fallbackCopy()
      }
      this.showCopied()
    } catch (error) {
      this.fallbackCopy()
      this.showCopied()
    }
  }

  fallbackCopy() {
    const textarea = document.createElement("textarea")
    textarea.value = this.textValue
    textarea.setAttribute("readonly", "")
    textarea.style.position = "absolute"
    textarea.style.left = "-9999px"
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand("copy")
    document.body.removeChild(textarea)
  }

  showCopied() {
    const defaultLabel = this.defaultLabelValue || (this.hasLabelTarget ? this.labelTarget.textContent : "")
    const copiedLabel = this.copiedLabelValue || defaultLabel

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = copiedLabel
    }

    if (this.hasStatusTarget) {
      this.statusTarget.textContent = copiedLabel
    }

    if (this.resetTimer) {
      clearTimeout(this.resetTimer)
    }

    this.resetTimer = setTimeout(() => {
      if (this.hasLabelTarget) {
        this.labelTarget.textContent = defaultLabel
      }
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = ""
      }
    }, this.resetDelayValue)
  }
}
