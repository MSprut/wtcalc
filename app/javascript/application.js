// Entry point for the build script in your package.json
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js").catch((err) => {
      console.error("[PWA] SW registration failed:", err);
    });
  });
}

import "@hotwired/turbo-rails";
import "bootstrap/dist/js/bootstrap.bundle.min.js";

// import * as bootstrap from "bootstrap"

// import "./source/file_field"
import "./source/tooltips"
