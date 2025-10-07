import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"
import "chartjs-adapter-date-fns"

import annotationPlugin from "chartjs-plugin-annotation"
Chart.register(annotationPlugin)

export default class extends Controller {
  connect() {
    this.destroy()

    // помощник: сдвиг ISO-даты на ±N дней без головной боли с часовыми поясами
// function shiftDay(iso /* 'YYYY-MM-DD' */, delta) {
//   const [y, m, d] = iso.split("-").map(Number)
//   const dt = new Date(Date.UTC(y, m - 1, d))
//   dt.setUTCDate(dt.getUTCDate() + delta)
//   const yy = dt.getUTCFullYear()
//   const mm = String(dt.getUTCMonth() + 1).padStart(2, "0")
//   const dd = String(dt.getUTCDate()).padStart(2, "0")
//   return `${yy}-${mm}-${dd}`
// }

    const raw = this.element.dataset.series || "[]"
    let data; try { data = JSON.parse(raw) } catch { return }
    if (!Array.isArray(data) || data.length === 0) return

    const avg = this.mavg(data, data.length)

    const startX = data[0]?.x, endX = data[data.length - 1]?.x

    const showBaseline = this.element.dataset.chartBaseline === "true"
    const baseline8 = 8
    const baseline12 = 12
    let showBaseline12 = false;

    let base = data,
        over = [],
        gap = [];
    
    if (showBaseline) {
      showBaseline12 = data.filter(p => { return p.y > baseline12 }).length > 0
      base = data.map(p => ({ x: p.x, y: Math.min(p.y ?? 0, p.y > baseline12 ? baseline12 : baseline8) }))
      over = data.map(p => ({ x: p.x, y: Math.max((p.y ?? 0) - (p.y > baseline12 ? baseline12 : baseline8), 0) }))
      gap  = data.map(p => ({ x: p.x, y: Math.max((p.y > baseline12 ? baseline12 : baseline8) - (p.y ?? 0), 0) })) // опционально
    }

    const datasets = [
      { type: "bar", label: "часы", data: base,
        stack: "hours", yAxisID: "y", borderWidth: 0,
        barPercentage: 0.8, categoryPercentage: 0.8,
        backgroundColor: "rgba(73, 164, 224, 0.6)", order: 2 
      },
      { type: "line", label: `среднее (${data.length}д)`, data: avg, yAxisID: "y",
        borderWidth: 2, pointRadius: 0, tension: 0.3, borderColor: "#0c8fcc",
        backgroundColor: "#0c8fcc", order: 1
      },
    ]

    if (showBaseline) {
      datasets.push(
          // включай этот датасет, если хочешь видеть «недобор»
        { type: "bar", label: "недобор до 8", data: gap,
          stack: "hours", yAxisID: "y", borderWidth: 0,
          barPercentage: 0.8, categoryPercentage: 0.8,
          backgroundColor: "#9fadc2ff", order: 2 /* приглушённый */
        },
        { type: "bar", label: "переработка", data: over,
          stack: "hours", yAxisID: "y", borderWidth: 0,
          barPercentage: 0.8, categoryPercentage: 0.8,
          backgroundColor: "#f8c46b" /* жёлтый/оранжевый */,
          order: 2 // поверх base/gap
        },
      )
    }
console.log(showBaseline12)
    this.chart = new Chart(this.element.getContext("2d"), {
      data: {
        datasets: datasets
      },
      options: {
        parsing: { xAxisKey: "x", yAxisKey: "y" },
        responsive: true,
        maintainAspectRatio: false,
        scales: { x: { type: "time", time: { unit: "day" } }, y: { beginAtZero: true } },
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { display: true, position: "top" },
          ...(showBaseline ? { annotation: {
              annotations: {
                norm8: {
                  type: "line",
                  yMin: baseline8, yMax: baseline8,              // горизонталь на уровне 8 ч
                  borderColor: "#ef4444", borderWidth: 2,
                  borderDash: [15, 10],
                  drawTime: "afterDatasetsDraw",               // поверх баров/линий
                  label: { enabled: true, content: "8ч", position: "end", color: "#ef4444",
                          backgroundColor: "transparent", order: 0 }
                },
                ...(showBaseline12 ? { norm12: {
                  type: "line",
                  yMin: baseline12, yMax: baseline12,              // горизонталь на уровне 8 ч
                  borderColor: "#ef4444", borderWidth: 2,
                  borderDash: [15, 10],
                  drawTime: "afterDatasetsDraw",               // поверх баров/линий
                  label: { enabled: true, content: "12ч", position: "end", color: "#ef4444",
                          backgroundColor: "transparent", order: 0 }
                }
              } : {})
              }
            }
          } : {})
        }
      }
    })
  }

  disconnect() { this.destroy() }
  destroy() { if (this.chart) { try { this.chart.destroy() } catch {}; this.chart = null } }

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

// // app/javascript/controllers/chart_controller.js
// import { Controller } from "@hotwired/stimulus"
// import Chart from "chart.js/auto"
// import "chartjs-adapter-date-fns"

// console.log("[chart] controller file loaded") // ← увидишь при успешном импорте

// export default class extends Controller {
//   connect() {
//     console.log("[chart] connect", this.element)

//     // прибьём старое на всякий
//     this.disconnect()

//     const raw = this.element.dataset.series || this.element.dataset.seriesBars || "[]"
//     let data
//     try { data = JSON.parse(raw) } catch (e) { console.error("[chart] bad JSON", e, raw); return }
//     if (!Array.isArray(data) || data.length === 0) { console.warn("[chart] empty data-series"); return }

//     if (!this.element.getAttribute("height")) this.element.style.minHeight = "160px"

//     const avg = this.mavg(data, 7)

//     this.chart = new Chart(this.element.getContext("2d"), {
//       data: {
//         datasets: [
//           { type: "bar",  label: "часы (день)", data, yAxisID: "y", borderWidth: 0, barPercentage: 0.8, categoryPercentage: 0.8 },
//           { type: "line", label: "среднее (7д)", data: avg, yAxisID: "y", borderWidth: 2, pointRadius: 0, tension: 0.3 }
//         ]
//       },
//       options: {
//         parsing: { xAxisKey: "x", yAxisKey: "y" },
//         maintainAspectRatio: false,
//         responsive: true,
//         interaction: { mode: "index", intersect: false },
//         scales: { x: { type: "time", time: { unit: "day" } }, y: { beginAtZero: true } },
//         plugins: { legend: { display: true, position: "top" } }
//       }
//     })

//     console.log("[chart] created")
//   }

//   disconnect() {
//     if (this.chart) { try { this.chart.destroy() } catch (_) {} this.chart = null; console.log("[chart] destroyed") }
//   }

//   mavg(arr, win) {
//     const out = [], buf = []; let sum = 0
//     for (let i = 0; i < arr.length; i++) {
//       const v = Number(arr[i].y) || 0
//       buf.push(v); sum += v
//       if (buf.length > win) sum -= buf.shift()
//       out.push({ x: arr[i].x, y: sum / Math.min(buf.length, win) })
//     }
//     return out
//   }
// }
