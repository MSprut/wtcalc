import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit(event) {
    // отложим, чтобы введённое значение успело примениться
    clearTimeout(this.t); this.t = setTimeout(() => this.element.requestSubmit(), 50)
  }
  enter(e) {
    if (e.key === "Enter") { e.preventDefault(); this.element.requestSubmit(); }
  }
  bounce(e) {
    // можно показать тост/подсветку строки по окончании сабмита
  }

  afterSave(e) {
    if (!e.detail?.success) return
    const fd = new FormData(this.element)
    const url = new URL(window.location)
    const p = url.searchParams
    const df = fd.get("date_from"), dt = fd.get("date_to"), uid = fd.get("filter_user_id")

    if (df) p.set("date_from", df)
    if (dt) p.set("date_to", dt)
    if (uid && uid.length > 0) p.set("filter_user_id", uid); else p.delete("filter_user_id")

    history.replaceState({}, "", `${url.pathname}?${p.toString()}`)
  }
}
