const CACHE = "savers-v10";
const SHELL = ["./", "./index.html", "./manifest.webmanifest", "./icons/apple-touch-icon.png", "./icons/icon-192.png", "./icons/icon-512.png"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// Stale-while-revalidate: open instantly (also offline), refresh the copy in the background.
self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  const cacheable = url.origin === self.location.origin || url.hostname === "fonts.googleapis.com" || url.hostname === "fonts.gstatic.com";
  if (!cacheable) return;
  e.respondWith(
    caches.open(CACHE).then(async (cache) => {
      if (req.mode === "navigate") {
        // Network first for the page so fixes arrive on the next open; cached copy when offline.
        try {
          // Skip the HTTP cache (GitHub Pages sets max-age=600) so updates show up on the next open.
          const res = await fetch(req, { cache: "no-store" });
          if (res && res.ok) cache.put("./index.html", res.clone());
          return res;
        } catch (err) {
          return (await cache.match("./index.html")) || Response.error();
        }
      }
      const key = req;
      const cached = await cache.match(key);
      const network = fetch(req)
        .then((res) => {
          if (res && (res.ok || res.type === "opaque")) cache.put(key, res.clone());
          return res;
        })
        .catch(() => cached);
      return cached || network;
    })
  );
});
