import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"
import "chartjs-adapter-date-fns"

export default class extends Controller {
  connect() {
    console.log("[chart] connect", this.element)

    // очистим прежний экземпляр на всякий случай
    this.disconnect()

    // берём данные: data-series или data-series-bars
    const raw = this.element.dataset.series || this.element.dataset.seriesBars || "[]"
    let data
    try {
      data = JSON.parse(raw)
    } catch (e) {
      console.error("[chart] bad JSON in data-series", e, raw)
      return
    }
    if (!Array.isArray(data) || data.length === 0) {
      console.warn("[chart] empty data-series")
      return
    }

    // небольшая страховка по высоте
    if (!this.element.getAttribute("height")) this.element.style.minHeight = "160px"

    const avg = this.mavg(data, 7)

    this.chart = new Chart(this.element.getContext("2d"), {
      data: {
        datasets: [
          { type: "bar",  label: "часы (день)", data, yAxisID: "y",
            borderWidth: 0, barPercentage: 0.8, categoryPercentage: 0.8 },
          { type: "line", label: "среднее (7д)", data: avg, yAxisID: "y",
            borderWidth: 2, pointRadius: 0, tension: 0.3 }
        ]
      },
      options: {
        parsing: { xAxisKey: "x", yAxisKey: "y" },
        maintainAspectRatio: false,
        responsive: true,
        interaction: { mode: "index", intersect: false },
        scales: { x: { type: "time", time: { unit: "day" } }, y: { beginAtZero: true } },
        plugins: { legend: { display: true, position: "top" } }
      }
    })

    console.log("[chart] created")
  }

  disconnect() {
    if (this.chart) {
      try { this.chart.destroy() } catch (_) {}
      this.chart = null
      console.log("[chart] destroyed")
    }
  }

  mavg(arr, win) {
    const out = [], buf = []; let sum = 0
    for (let i = 0; i < arr.length; i++) {
      const v = Number(arr[i].y) || 0
      buf.push(v); sum += v
      if (buf.length > win) sum -= buf.shift()
      out.push({ x: arr[i].x, y: sum / Math.min(buf.length, win) })
    }
    return out
  }
}
