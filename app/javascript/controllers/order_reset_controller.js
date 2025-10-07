import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    storageKey: String,
    input: { type: String, default: "#wt_order" },
    formSelector: { type: String, default: 'form[action$="/worktime/summary"]' }
  }

  reset() {
    // 1) очистим локальное сохранение порядка
    try {
      if (this.hasStorageKeyValue) localStorage.removeItem(this.storageKeyValue)
      else this._removeDerived()
    } catch {}

    // 2) очистим hidden input и order в URL
    const input = document.querySelector(this.inputValue)
    if (input) input.value = ""

    const url = new URL(window.location.href)
    url.searchParams.delete("order")
    history.replaceState({}, "", url.toString())

    // 3) перезапросим страницу с дефолтным порядком
    const form = document.querySelector(this.formSelectorValue) || input?.form
    form?.requestSubmit()
  }

  _removeDerived() {
    const url = new URL(window.location.href)
    const pick = k => url.searchParams.get(k) || ""
    const key = `wt-matrix-${pick("date_from")}-${pick("date_to")}-${pick("filter_user_id") || "all"}`
    localStorage.removeItem(key)
  }
}
