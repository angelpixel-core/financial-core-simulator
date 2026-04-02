import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "display"]

  activate(event) {
    if (!this.hasInputTarget) return
    if (this.element.classList.contains("fx-history-cell--editing")) return
    this.element.classList.add("fx-history-cell--editing")
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  commit(event) {
    if (!this.element.classList.contains("fx-history-cell--editing")) return
    this.element.classList.remove("fx-history-cell--editing")
    this.submitIfChanged()
  }

  handleKey(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.commit()
      return
    }

    if (event.key === "Escape") {
      event.preventDefault()
      this.resetValue()
      this.element.classList.remove("fx-history-cell--editing")
      this.inputTarget.blur()
    }
  }

  stop(event) {
    event.stopPropagation()
  }

  submitIfChanged() {
    const currentValue = this.inputTarget.value.trim()
    const initialValue = (this.inputTarget.dataset.initialValue || "").trim()

    if (currentValue === "" || currentValue === initialValue) return

    const form = this.inputTarget.form
    if (!form) return

    if (typeof form.requestSubmit === "function") {
      form.requestSubmit()
    } else {
      form.submit()
    }
  }

  resetValue() {
    this.inputTarget.value = this.inputTarget.dataset.initialValue || ""
  }
}
