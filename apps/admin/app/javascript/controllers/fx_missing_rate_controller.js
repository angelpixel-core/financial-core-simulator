import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  close(event) {
    if (event) event.preventDefault()
    this.element.remove()
  }
}
