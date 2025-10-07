// app/javascript/controllers/progress_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values  = { id: Number, interval: { type: Number, default: 1000 }, keepUrl: { type: Boolean, default: false } }
  static targets = ["bar", "percent", "status", "name"]

  connect() {
    if (this._connected) return
    this._connected = true
    this._tick = this.tick.bind(this)
    this.timer = setInterval(this._tick, this.intervalValue)
    this.tick()
  }
  disconnect() { this._connected = false; if (this.timer) clearInterval(this.timer) }

  async tick() {
    try {
      const r = await fetch(`/import_files/${this.idValue}.json`, { headers: { Accept: "application/json" }, cache: "no-store" })
      if (!r.ok) return
      const { progress, status, filename } = await r.json()
      if (this.hasBarTarget)     this.barTarget.style.width = `${progress}%`
      if (this.hasPercentTarget) this.percentTarget.textContent = progress
      if (this.hasStatusTarget)  this.statusTarget.textContent = status || ""
      if (this.hasNameTarget && filename) this.nameTarget.textContent = filename
      if (progress >= 100 || /готово/i.test(status || "")) this.finish()
    } catch {}
  }

  async finish() {
    if (this.timer) { clearInterval(this.timer); this.timer = null }

    // 1) убрать import_file_id из адресной строки
    if (!this.keepUrlValue) {
      const url = new URL(window.location.href)
      url.searchParams.delete("import_file_id")
      history.replaceState({}, "", url)
    }

    // 2) подтянуть свежую таблицу
    try {
      const url = new URL("/csv/table", window.location.origin)
      // сохраняем текущие параметры фильтра (если есть)
      url.search = window.location.search.replace(/^\?/, "")
      const r = await fetch(url.toString(), { headers: { Accept: "text/html" }, cache: "no-store" })
      if (r.ok) {
        const html = await r.text()
        const box = document.getElementById("csv_table")
        if (box) box.innerHTML = html
      }
    } catch {}

    // 3) спрятать карточку прогресса
    this.element.classList.add("d-none")
  }
}


// // app/javascript/controllers/progress_controller.js
// import { Controller } from "@hotwired/stimulus"

// export default class extends Controller {
//   static values = {
//     id: Number,
//     interval: { type: Number, default: 1000 },
//     keepUrl: { type: Boolean, default: false } // оставить import_file_id в адресе?
//   }
//   static targets = ["bar", "percent", "status", "name"]

//   connect() {
//     // защита от двойного подключения
//     if (this._connected) return
//     this._connected = true

//     this._tick = this.tick.bind(this)
//     this.timer = setInterval(this._tick, this.intervalValue)
//     this.tick()
//   }

//   disconnect() {
//     this._connected = false
//     if (this.timer) clearInterval(this.timer)
//   }

//   async tick() {
//     try {
//       const r = await fetch(`/import_files/${this.idValue}.json`, {
//         headers: { Accept: "application/json" },
//         cache: "no-store"
//       })
//       if (!r.ok) return
//       const { progress, status, filename } = await r.json()

//       if (this.hasBarTarget)     this.barTarget.style.width = `${progress}%`
//       if (this.hasPercentTarget) this.percentTarget.textContent = progress
//       if (this.hasStatusTarget)  this.statusTarget.textContent = status || ""
//       if (this.hasNameTarget && filename) this.nameTarget.textContent = filename

//       const done = progress >= 100 || /готово/i.test(status || "")
//       if (done) this.finish()
//     } catch { /* молчим */ }
//   }

//   finish() {
//     if (this.timer) { clearInterval(this.timer); this.timer = null }
//     // 1) убираем import_file_id из адресной строки, чтобы при перезагрузке карточка не появлялась снова
//     if (!this.keepUrlValue) {
//       const url = new URL(window.location.href)
//       url.searchParams.delete("import_file_id")
//       history.replaceState({}, "", url)
//     }
//     // 2) оставим карточку как «Готово» или спрячем:
//     this.element.classList.add("d-none")

//     // 3) (опционально) перерисовать таблицу.
//     // Проще всего — мягкая перезагрузка страницы:
//     // location.reload()
//     // Или запроси отдельный endpoint, который отдаёт только таблицу, и подмени innerHTML.
//   }
// }
