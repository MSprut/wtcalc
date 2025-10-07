import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = { input: String, storageKey: String }

  connect() {
    this.applySavedOrder()

    this.sortable = Sortable.create(this.element, {
      handle: ".drag-handle",
      animation: 150,
      ghostClass: "table-row-ghost",
      onEnd: () => this.persist()
    })
  }

  disconnect() { this.sortable?.destroy() }

  key() {
    // приоритет — явный ключ из data-reorder-storage-key-value
    if (this.hasStorageKeyValue) return this.storageKeyValue
    // запасной вариант: по текущему пути и параметрам
    const url = new URL(window.location.href)
    const pick = k => url.searchParams.get(k) || ""
    return `wt-matrix-${pick("date_from")}-${pick("date_to")}-${pick("filter_user_id")}`
  }

  applySavedOrder() {
    try {
      const raw = localStorage.getItem(this.key())
      if (!raw) return
      const ids = raw.split(",").map(x => x.trim()).filter(Boolean)
      if (!ids.length) return

      const rowsById = {}
      this.element.querySelectorAll("tr[data-user-id]").forEach(tr => rowsById[tr.dataset.userId] = tr)

      // Соберём заново tbody в нужном порядке
      const frag = document.createDocumentFragment()
      ids.forEach(id => { const tr = rowsById[id]; if (tr) { frag.appendChild(tr); delete rowsById[id] } })
      // добросим «хвост» — те, кого не было в сохранённом порядке
      Object.values(rowsById).forEach(tr => frag.appendChild(tr))
      this.element.appendChild(frag)

      // заполним скрытое поле, чтобы сервер применил тот же порядок
      const input = document.querySelector(this.inputValue || "#wt_order")
      if (input) input.value = ids.join(",")
    } catch {}
  }

  persist() {
    const ids = Array.from(this.element.querySelectorAll("tr[data-user-id]")).map(tr => tr.dataset.userId)
    const order = ids.join(",")

    // 1) скрытое поле для сервера
    const input = document.querySelector(this.inputValue || "#wt_order")
    if (input) input.value = order

    // 2) локальное хранение для F5
    try { localStorage.setItem(this.key(), order) } catch {}

    // 3) отправим форму фильтра
    const form = input?.form || document.querySelector('form[action$="/worktime/summary"]')
    form?.requestSubmit()
  }
}


// import { Controller } from "@hotwired/stimulus"
// import Sortable from "sortablejs"

// export default class extends Controller {
//   static values = { input: String } // селектор скрытого поля (:order)

//   connect() {
//     // табличное тело (<tbody>)
//     this.sortable = Sortable.create(this.element, {
//       handle: ".drag-handle",
//       animation: 150,
//       ghostClass: "table-row-ghost",
//       onEnd: () => this.persist()
//     })
//   }

//   disconnect() {
//     this.sortable?.destroy()
//   }

//   persist() {
//     const ids = Array.from(this.element.querySelectorAll("tr[data-user-id]"))
//       .map(tr => tr.dataset.userId)

//     const input = document.querySelector(this.inputValue || "#wt_order")
//     if (input) input.value = ids.join(",")

//     // отправляем форму фильтра (та же, что и для дат/сотрудника)
//     const form = input?.form || document.querySelector('form[action$="/worktime"]')
//     form?.requestSubmit()
//   }
// }
