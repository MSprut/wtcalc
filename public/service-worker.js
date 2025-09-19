/* public/service-worker.js */
const CACHE_NAME = "wtcalc-v1";
const CORE_ASSETS = [
  "/",                    // главная
  "/manifest.json",
  "/offline.html",
  "/icons/icon-192.png",
  "/icons/icon-512.png",
];

// Установка: кладем базовые файлы в кэш
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(CORE_ASSETS))
  );
  self.skipWaiting(); // сразу активируем новую версию
});

// Активация: чистим старые кэши
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.map((k) => (k === CACHE_NAME ? null : caches.delete(k))))
    )
  );
  self.clients.claim();
});

// Стратегии: HTML — сеть-в-приоритете; остальное — кэш-в-приоритете с подкачкой из сети
self.addEventListener("fetch", (event) => {
  const { request } = event;

  // Только GET и то, что под нашим контролем
  if (request.method !== "GET" || new URL(request.url).origin !== self.location.origin) {
    return;
  }

  const isHTML = request.headers.get("accept")?.includes("text/html");

  if (isHTML) {
    // Network-first для страниц: офлайн — offline.html
    event.respondWith(
      fetch(request)
        .then((resp) => {
          const copy = resp.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(request, copy));
          return resp;
        })
        .catch(async () => {
          const cached = await caches.match(request);
          return cached || caches.match("/offline.html");
        })
    );
  } else {
    // Cache-first для статики (CSS/JS/изображения и т.д.)
    event.respondWith(
      caches.match(request).then((cached) => {
        const fetchAndUpdate = fetch(request)
          .then((resp) => {
            // Успешную сетевую копию подкладываем в кэш
            if (resp.ok) {
              const copy = resp.clone();
              caches.open(CACHE_NAME).then((cache) => cache.put(request, copy));
            }
            return resp;
          })
          .catch(() => cached); // сеть упала -> что есть в кэше

        return cached || fetchAndUpdate;
      })
    );
  }
});