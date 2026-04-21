import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput", "fileIcon", "submitButton", "previewSubmit", "actionLabel", "actionIcon"]
  static values = {
    defaultIcon: String,
    readyIcon: String,
    loadLabel: String,
    runLabel: String,
    processing: Boolean,
  }

  connect() {
    this.refreshState()
  }

  onFileChange() {
    this.refreshState()
  }

  onSubmitEnd(event) {
    if (this.isPreviewSubmission(event)) return

    this.processingValue = true
    this.refreshState()
  }

  handleReviewClick(event) {
    event.preventDefault()

    if (!this.hasFileInputTarget) return
    const hasFile = this.fileInputTarget.files && this.fileInputTarget.files.length > 0

    if (!hasFile) {
      this.fileInputTarget.click()
      return
    }

    if (this.hasPreviewSubmitTarget) {
      this.element.requestSubmit(this.previewSubmitTarget)
    }
  }

  clearFile(event) {
    if (event) event.preventDefault()
    if (!this.hasFileInputTarget) return

    this.fileInputTarget.value = ""
    this.refreshState()
  }

  isPreviewSubmission(event) {
    const submitter = event?.detail?.formSubmission?.submitter || event?.detail?.submitter || event?.submitter

    return submitter?.dataset?.fxRateUploadPreviewSubmit === "true"
  }

  refreshState() {
    const hasFile = this.hasFileInputTarget && this.fileInputTarget.files && this.fileInputTarget.files.length > 0
    const isReady = hasFile || this.processingValue
    const isLoading = this.processingValue

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = !hasFile || isLoading
      this.submitButtonTarget.classList.toggle("overview__icon-button--primary", isReady)
      this.submitButtonTarget.classList.toggle("fx-history-action--ready", isReady)
      this.submitButtonTarget.classList.toggle("fx-history-action--loading", isLoading)
      const title = isReady ? this.runLabelValue : this.loadLabelValue
      this.submitButtonTarget.setAttribute("title", title)
      this.submitButtonTarget.setAttribute("aria-label", title)
    }

    if (this.hasActionLabelTarget) {
      this.actionLabelTarget.hidden = isReady
      this.actionLabelTarget.textContent = this.loadLabelValue
    }

    if (this.hasActionIconTarget) {
      this.actionIconTarget.hidden = !isReady
    }

    if (this.hasFileIconTarget) {
      this.fileIconTarget.src = hasFile ? this.readyIconValue : this.defaultIconValue
    }
  }
}
