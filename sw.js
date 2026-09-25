const CACHE = "savers-v39";
// The Gemini voice clips live in their own cache and survive every update.
const KEEP = [CACHE, "savers-voz"];
const SHELL = ["./", "./index.html", "./manifest.webmanifest", "./icons/apple-touch-icon.png", "./icons/icon-192.png", "./icons/icon-512.png"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => !KEEP.includes(k)).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// Stale-while-revalidate: open instantly (also offline), refresh the copy in the background.
self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  const cacheable = url.origin === self.location.origin || url.hostname === "fonts.googleapis.com" || url.hostname === "fonts.gstatic.com" ||
    // The Firebase SDK, so the app opens offline with the cloud code ready (the version is in the path).
    (url.hostname === "www.gstatic.com" && url.pathname.startsWith("/firebasejs/"));
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

// A notification from the savers-avisos worker. iOS needs one shown for every push.
self.addEventListener("push", (e) => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (err) {}
  e.waitUntil(self.registration.showNotification(d.title || "SAVERS", {
    body: d.body || "",
    tag: d.tag || "savers",
    icon: "icons/icon-192.png",
    data: { url: d.url || "./" }
  }));
});

// Tapping it opens SAVERS on Hoy: the open app is told to go there, or the app opens.
self.addEventListener("notificationclick", (e) => {
  e.notification.close();
  const url = new URL((e.notification.data && e.notification.data.url) || "./", self.registration.scope).href;
  e.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((list) => {
      const c = list[0];
      if (c) {
        c.postMessage({ go: "today" });
        return c.focus ? c.focus().catch(() => self.clients.openWindow(url)) : self.clients.openWindow(url);
      }
      return self.clients.openWindow(url);
    })
  );
});
