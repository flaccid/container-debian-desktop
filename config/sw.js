const CACHE = "debian-desktop-v1";

self.addEventListener("install", (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE).then((cache) =>
      cache.addAll([
        "/",
        "/vnc.html",
        "/vnc_auto.html",
        "/manifest.json",
        "/icon-192.png",
        "/icon-512.png",
        "/openlogo-debianV2.svg",
        "/novnc-dark.css",
        "/audio-plugin.js",
      ])
    )
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(clients.claim());
});

self.addEventListener("fetch", (event) => {
  if (event.request.mode === "websocket") return;
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        const clone = response.clone();
        caches.open(CACHE).then((cache) => cache.put(event.request, clone));
        return response;
      })
      .catch(() => caches.match(event.request))
  );
});
