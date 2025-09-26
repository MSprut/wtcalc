// Entry point for the build script in your package.json
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js").catch((err) => {
      console.error("[PWA] SW registration failed:", err);
    });
  });
}

import { Application } from "@hotwired/stimulus"
const application = Application.start()
application.debug = true

import registerControllers from "./controllers"
registerControllers(application)

// const context = require.context("./controllers", true, /\.js$/)
// context.keys().forEach((key) => {
//   const identifier = key.replace("./", "").replace(".js", "").replace("_controller", "")
//   application.register(identifier, context(key).default)
// })

import "@hotwired/turbo-rails";
import "bootstrap/dist/js/bootstrap.bundle.min.js";

// import * as bootstrap from "bootstrap"

// import "./source/file_field"
import "./source/tooltips";
// import "./source/chart";


// сохраняем фильтры в URL после сабмитов (по дням/дефолт/глобальный)
document.addEventListener("turbo:submit-end", (e) => {
  if (!e.detail?.success) return;
  const form = e.target;
  if (!(form instanceof HTMLFormElement)) return;

  const fd = new FormData(form);
  const url = new URL(window.location);
  const p = url.searchParams;

  const df = fd.get("date_from");
  const dt = fd.get("date_to");
  const uid = fd.get("user_id");

  if (df) p.set("date_from", df);
  if (dt) p.set("date_to", dt);
  if (uid && String(uid).length > 0) p.set("user_id", uid); else p.delete("user_id");

  history.replaceState({}, "", `${url.pathname}?${p.toString()}`);
});

// — фикс сворачивания «Дни»: запоминаем ВСЕ открытые и восстанавливаем
const openLbIds = new Set();
document.addEventListener("turbo:before-stream-render", () => {
  openLbIds.clear();
  document.querySelectorAll('div[id^="lb_user_"].collapse.show').forEach(el => openLbIds.add(el.id));
});
document.addEventListener("turbo:render", () => {
  const Collapse = window.bootstrap?.Collapse;
  openLbIds.forEach((id) => {
    const el = document.getElementById(id);
    if (!el) return;
    if (Collapse) {
      const inst = Collapse.getOrCreateInstance(el, { toggle: false });
      inst.show();
    } else {
      el.classList.add("show");
    }
  });
  openLbIds.clear();
});
// ——— сохранить/восстановить раскрытый collapse «Дни» при обновлении строки пользователя
// const openLbs = new Set();

// document.addEventListener("turbo:before-stream-render", (e) => {
//   const el = e.target;
//   const action = el.getAttribute("action");
//   const target = el.getAttribute("target") || "";

//   // обновление контейнера строк (tbody) ИЛИ заголовка строки (tr)
//   if ((action === "update" || action === "replace") &&
//       (target.startsWith("rows_user_") || target.startsWith("row_user_"))) {
//     // ищем ближайший tbody и его data-lb-id
//     let lbId = null;
//     let host = document.getElementById(target);
//     if (!host && target.startsWith("row_user_")) {
//       host = document.getElementById(target);
//     }
//     const tbody = host?.closest ? host.closest("tbody") : document.getElementById(target);
//     lbId = tbody?.dataset?.lbId;

//     // запасной путь: собрать из user_id
//     if (!lbId && (target.startsWith("row_user_") || target.startsWith("rows_user_"))) {
//       const uid = target.replace(/^rows?_user_/, "");
//       lbId = `lb_user_${uid}`;
//     }

//     const lb = lbId && document.getElementById(lbId);
//     if (lb && lb.classList.contains("show")) openLbs.add(lbId);
//   }
// });

// document.addEventListener("turbo:render", () => {
//   // восстановить ранее открытые collapse
//   openLbs.forEach((id) => {
//     const el = document.getElementById(id);
//     if (!el) return;
//     const Collapse = window.bootstrap?.Collapse;
//     if (Collapse) {
//       const inst = Collapse.getOrCreateInstance(el, { toggle: false });
//       inst.show();
//     } else {
//       el.classList.add("show");
//     }
//   });
//   openLbs.clear();
// });

// // ——— СОХРАНЯЕМ ФИЛЬТРЫ В URL ПОСЛЕ УСПЕШНЫХ САБМИТОВ (по дням/дефолт/глобально)
// document.addEventListener("turbo:submit-end", (e) => {
//   if (!e.detail?.success) return;
//   const form = e.target;
//   if (!(form instanceof HTMLFormElement)) return;

//   const fd = new FormData(form);
//   const url = new URL(window.location);
//   const p = url.searchParams;

//   const df = fd.get("date_from");
//   const dt = fd.get("date_to");
//   const uid = fd.get("user_id");

//   if (df) p.set("date_from", df);
//   if (dt) p.set("date_to", dt);
//   if (uid && String(uid).length > 0) p.set("user_id", uid); else p.delete("user_id");

//   history.replaceState({}, "", `${url.pathname}?${p.toString()}`);
// });
