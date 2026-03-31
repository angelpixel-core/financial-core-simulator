import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit(event) {
    const form = event?.target?.form || this.element
    if (!form) return

    if (typeof form.requestSubmit === "function") {
      form.requestSubmit()
    } else {
      form.submit()
    }
  }
}
