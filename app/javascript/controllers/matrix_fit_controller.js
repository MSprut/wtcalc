import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { days: Number, minDay: { type: Number, default: 24 }, maxDay: { type: Number, default: 48 } }

  connect() {
    this.ro = new ResizeObserver(() => this.fit())
    this.ro.observe(this.element)
    document.addEventListener("turbo:render", this._onRender = () => this.fit())
    this.fit()
  }

  disconnect() {
    this.ro?.disconnect()
    document.removeEventListener("turbo:render", this._onRender)
  }

  fit() {
    const wrap  = this.element
    const table = wrap.querySelector("table.matrix-table")
    if (!table) return

    const head  = table.tHead?.rows?.[0]
    if (!head) return

    const ths = Array.from(head.cells)
    // ожидаем порядок: [ручка], ФИО, ... даты ..., Итого, Δч
    const dragW  = ths[0]?.offsetWidth || 0
    const nameTh = head.querySelector("th.name")
    const totalTh= head.querySelector("th.total-h")
    const deltaTh= head.querySelector("th.delta-h")

    const nameW  = Math.ceil(nameTh?.offsetWidth || 0)
    const totalW = Math.ceil(totalTh?.offsetWidth || 0)
    const deltaW = Math.ceil(deltaTh?.offsetWidth || 0)

    const wrapW  = wrap.clientWidth
    const days   = this.daysValue || table.dataset.days || 1

    // суммарная фиксированная часть
    const fixed = dragW + nameW + totalW + deltaW
    // запас на бордеры/паддинги
    const gutter = 8 + days // примерно

    let dayW = Math.floor((wrapW - fixed - gutter) / days)
    const minW = this.minDayValue
    const maxW = this.maxDayValue
    const scrollNeeded = dayW < minW

    dayW = Math.min(Math.max(dayW, minW), maxW)

    // применяем CSS-переменные к таблице
    table.style.setProperty("--name-w",  `${nameW}px`)
    table.style.setProperty("--total-w", `${totalW}px`)
    table.style.setProperty("--delta-w", `${deltaW}px`)
    table.style.setProperty("--day-w",   `${dayW}px`)

    // режим прокрутки, если не помещается
    wrap.classList.toggle("is-scrollable", scrollNeeded)
  }
}
