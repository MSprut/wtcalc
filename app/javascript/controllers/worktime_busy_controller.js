import { Controller } from "@hotwired/stimulus"

// Вешаем на общий контейнер (row), чтобы "видеть" и форму фильтра, и секцию с содержимым
export default class extends Controller {
  static targets = ["overlay"]

  connect() {
    // события Turbo Drive (работают и при GET с формой, и при переходах)
    this._start = this.start.bind(this)
    this._stop  = this.stop.bind(this)

    document.addEventListener("turbo:before-fetch-request", this._start)
    document.addEventListener("turbo:fetch-request-error",  this._stop)
    document.addEventListener("turbo:render",                this._stop)
  }

  disconnect() {
    document.removeEventListener("turbo:before-fetch-request", this._start)
    document.removeEventListener("turbo:fetch-request-error",  this._stop)
    document.removeEventListener("turbo:render",               this._stop)
  }

  // дергаем при change на полях фильтра (см. разметку ниже)
  submit(e) {
    this.start()
    // если change был на input/select — сабмитим его форму
    const form = e.target.form || this.element.querySelector("form")
    if (form) form.requestSubmit()
  }

  start() {
    if (this.hasOverlayTarget) this.overlayTarget.classList.remove("d-none")
  }

  stop() {
    if (this.hasOverlayTarget) this.overlayTarget.classList.add("d-none")
  }
}
