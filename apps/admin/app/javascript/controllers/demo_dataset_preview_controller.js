import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame"]

  start(event) {
    if (!this.isPreviewSubmission(event)) return

    this.element.classList.add("demo-dataset-preview--open", "demo-dataset-preview--loading")
    this.markBusy(true)
  }

  finish(event) {
    if (!this.isPreviewSubmission(event)) return

    this.element.classList.remove("demo-dataset-preview--loading")
    this.markBusy(false)
  }

  open() {
    this.element.classList.add("demo-dataset-preview--open")
    this.element.classList.remove("demo-dataset-preview--loading")
    this.markBusy(false)
  }

  close(event) {
    if (event) event.preventDefault()

    this.element.classList.remove("demo-dataset-preview--open", "demo-dataset-preview--loading")
    if (this.hasFrameTarget) this.frameTarget.innerHTML = ""
    this.markBusy(false)
  }

  isPreviewSubmission(event) {
    const submitter =
      event?.detail?.formSubmission?.submitter ||
      event?.detail?.submitter ||
      event?.submitter

    return submitter?.dataset?.demoDatasetPreviewSubmit === "true"
  }

  markBusy(isBusy) {
    if (!this.hasFrameTarget) return

    if (isBusy) {
      this.frameTarget.setAttribute("aria-busy", "true")
    } else {
      this.frameTarget.removeAttribute("aria-busy")
    }
  }
}
