import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  connect() {
    this._timer = null
    this._busy  = false
  }

  // мгновенная отправка (для select/date)
  submit() {
    if (this._busy) return
    this._busy = true
    this.element.requestSubmit()
  }

  // отложенная отправка (для текстовых полей)
  debounced() {
    if (this._busy) return
    clearTimeout(this._timer)
    this._timer = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  // чтобы Enter не открывал новую страницу раньше времени
  preventEnter(e) {
    if (e.key === "Enter") e.preventDefault()
  }

  // сбрасываем флаг после завершения запроса
  done() {
    this._busy = false
  }
}
