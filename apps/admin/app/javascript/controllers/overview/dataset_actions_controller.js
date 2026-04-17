import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput", "fileIcon", "submitButton", "previewSubmit"]
  static values = {
    defaultIcon: String,
    readyIcon: String
  }

  connect() {
    this.refreshState()
  }

  onFileChange() {
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

  refreshState() {
    const hasFile = this.hasFileInputTarget && this.fileInputTarget.files && this.fileInputTarget.files.length > 0

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = !hasFile
    }

    if (this.hasFileIconTarget) {
      this.fileIconTarget.src = hasFile ? this.readyIconValue : this.defaultIconValue
    }
  }
}
