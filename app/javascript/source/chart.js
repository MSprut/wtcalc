import Chart from "chart.js/auto";
import "chartjs-adapter-date-fns";

// простые логи (точно видны в консоли)
const log = (...a) => console.log("[chart]", ...a);

// хранит уже инициализированные канвасы
const inited = new WeakSet();

function movingAverage(data, win = 7) {
  const out = [], buf = []; let sum = 0;
  for (let i = 0; i < data.length; i++) {
    const v = Number(data[i].y) || 0;
    buf.push(v); sum += v;
    if (buf.length > win) sum -= buf.shift();
    out.push({ x: data[i].x, y: sum / Math.min(buf.length, win) });
  }
  return out;
}

function initCanvas(el) {
  if (!el || inited.has(el)) return;          // уже инициализирован
  const json = el.dataset.series || el.dataset.seriesBars || "[]";
  let bars;
  try { bars = JSON.parse(json); } catch (e) { console.error("[chart] bad JSON", e, json); return; }
  const line = movingAverage(bars, 7);
  const base = bars.map(p => ({ x: p.x, y: 8 }))
console.log(base)
  // уничтожим, если по какой-то причине есть старый
  if (el._chart) { try { el._chart.destroy(); } catch (_) {} }

  // на всякий случай фиксируем размеры
  el.style.display = "block";
  el.style.minHeight = el.getAttribute("height") ? "" : "160px";

  el._chart = new Chart(el.getContext("2d"), {
    data: {
      datasets: [
        { type: "bar",  label: "часы (день)", data: bars, yAxisID: "y",
          borderWidth: 0, barPercentage: 0.8, categoryPercentage: 0.8 },
        { type: "line", label: "среднее (7д)", data: line, yAxisID: "y",
          borderWidth: 2, pointRadius: 0, tension: 0.3, borderColor: "#035d99ff" },
        { type: "line", label: "8ч", data: base, yAxisID: "y",
          borderColor: "#ef4444", borderWidth: 2, pointRadius: 0, tension: 0,
          borderDash: [6, 4]
        }
      ]
    },
    options: {
      parsing: { xAxisKey: "x", yAxisKey: "y" },
      maintainAspectRatio: false,
      responsive: true,
      scales: { x: { type: "time", time: { unit: "day" } }, y: { beginAtZero: true } },
      interaction: { mode: "index", intersect: false },
      plugins: { legend: { display: true, position: "top" } }
    }
  });

  inited.add(el);
  log("created");
}

export function initCharts(root = document) {
  const list = root.querySelectorAll("#worktime_chart canvas[data-series], #worktime_chart canvas[data-series-bars]");
  log("scan", list.length);
  list.forEach(initCanvas);
}

export function destroyCharts(root = document) {
  root.querySelectorAll("#worktime_chart canvas[data-series], #worktime_chart canvas[data-series-bars]")
      .forEach((el) => {
        if (el._chart) { try { el._chart.destroy(); } catch (_) {} }
        delete el._chart;
        // WeakSet само «забудет» el, когда DOM-узел исчезнет
      });
  log("destroyed");
}

// ТОЛЬКО эти хуки — без лишних событий
export function installChartHooks() {
  document.addEventListener("turbo:load",       () => initCharts(document));
  document.addEventListener("turbo:frame-load", (e) => initCharts(e.target));

  // перед заменой графика — гасим старые экземпляры
  document.addEventListener("turbo:before-stream-render", (e) => {
    if (e.target.getAttribute("action") === "replace" &&
        e.target.getAttribute("target") === "worktime_chart") {
      destroyCharts(document);
    }
  });

  // после применения стримов канвас новый → один раз инициализируем
  document.addEventListener("turbo:render",     () => initCharts(document));
}

// для ручной проверки в консоли
if (typeof window !== "undefined") {
  window.__wt_initCharts = () => initCharts(document);
  window.__wt_destroyCharts = () => destroyCharts(document);
}
