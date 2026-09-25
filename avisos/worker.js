// SAVERS avisos: sends a push notification to one iPhone at an exact time.
// Each device is a Durable Object named by a random token that only the phone knows.
// It keeps the phone's push subscription and the notifications waiting to go out,
// and its alarm fires when the next one is due. Nothing else about you is stored here.
import { DurableObject } from "cloudflare:workers";

const ORIGINS = ["https://ezratawachi.github.io", "http://localhost:8791"];
const MAX_AHEAD = 24 * 3600 * 1000; // a notification can be set up to a day ahead
const MAX_PENDING = 20;

export default {
  async fetch(req, env) {
    const origin = req.headers.get("Origin") || "";
    const cors = {
      "Access-Control-Allow-Origin": ORIGINS.includes(origin) ? origin : ORIGINS[0],
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
      "Vary": "Origin"
    };
    if (req.method === "OPTIONS") return new Response(null, { headers: cors });
    const reply = (status, body) => Response.json(body || { ok: status < 300 }, { status, headers: cors });
    if (req.method !== "POST") return reply(405);

    // The app sends text/plain so the request needs no preflight and can outlive the page.
    let b;
    try { b = JSON.parse(await req.text()); } catch (e) { return reply(400); }
    if (!b || typeof b.device !== "string" || !/^[0-9a-f]{32}$/.test(b.device)) return reply(400);
    const box = env.INBOX.get(env.INBOX.idFromName(b.device));
    const path = new URL(req.url).pathname;

    if (path === "/subscribe") {
      const s = b.sub;
      if (!s || typeof s.endpoint !== "string" || !s.keys || !s.keys.p256dh || !s.keys.auth) return reply(400);
      if (!/^https:\/\/([a-z0-9-]+\.)*(push\.apple\.com|googleapis\.com|mozilla\.com|windows\.com)\//.test(s.endpoint)) return reply(400);
      await box.subscribe({ endpoint: s.endpoint, keys: { p256dh: s.keys.p256dh, auth: s.keys.auth } });
      return reply(200);
    }
    if (path === "/schedule") {
      const n = b.note;
      const at = n && Number(n.at);
      if (!n || !/^[a-z0-9-]{1,32}$/.test(n.id) || !at || at > Date.now() + MAX_AHEAD) return reply(400);
      const res = await box.schedule({
        id: n.id, at,
        title: String(n.title || "").slice(0, 120),
        body: String(n.body || "").slice(0, 240),
        url: String(n.url || "./").slice(0, 200)
      });
      return reply(res.ok ? 200 : 409, res);
    }
    if (path === "/cancel") {
      if (typeof b.id !== "string") return reply(400);
      await box.cancel(b.id);
      return reply(200);
    }
    return reply(404);
  }
};

export class Inbox extends DurableObject {
  async subscribe(sub) {
    await this.ctx.storage.put("sub", sub);
  }

  async schedule(note) {
    if (!(await this.ctx.storage.get("sub"))) return { ok: false, error: "no-sub" };
    const pending = (await this.ctx.storage.get("pending")) || {};
    pending[note.id] = note;
    if (Object.keys(pending).length > MAX_PENDING) return { ok: false, error: "full" };
    await this.ctx.storage.put("pending", pending);
    await this.arm(pending);
    return { ok: true };
  }

  async cancel(id) {
    const pending = (await this.ctx.storage.get("pending")) || {};
    delete pending[id];
    await this.ctx.storage.put("pending", pending);
    await this.arm(pending);
  }

  async arm(pending) {
    const times = Object.values(pending).map((n) => n.at);
    if (times.length) await this.ctx.storage.setAlarm(Math.min(...times));
    else await this.ctx.storage.deleteAlarm();
  }

  async alarm() {
    const pending = (await this.ctx.storage.get("pending")) || {};
    const sub = await this.ctx.storage.get("sub");
    const now = Date.now();
    for (const n of Object.values(pending)) {
      if (n.at > now + 500) continue;
      delete pending[n.id];
      if (!sub) continue;
      const status = await sendPush(this.env, sub, { title: n.title, body: n.body, tag: n.id, url: n.url });
      console.log("push", n.id, status);
      // 404/410: the phone dropped this subscription; it subscribes again from Ajustes.
      if (status === 404 || status === 410) await this.ctx.storage.delete("sub");
      // Anything else that failed is retried by the alarm (it throws, so Cloudflare runs it again).
      else if (status >= 500 || status === 429) { pending[n.id] = n; await this.ctx.storage.put("pending", pending); throw new Error("push " + status); }
    }
    await this.ctx.storage.put("pending", pending);
    await this.arm(pending);
  }
}

/* ---------- Web Push: VAPID (RFC 8292) and aes128gcm encryption (RFC 8291) ---------- */
const enc = new TextEncoder();

function b64u(bytes) {
  let s = "";
  for (const b of new Uint8Array(bytes)) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function unb64u(str) {
  const s = atob(str.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((str.length + 3) % 4));
  return Uint8Array.from(s, (c) => c.charCodeAt(0));
}
function concat(...parts) {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let i = 0;
  for (const p of parts) { out.set(p, i); i += p.length; }
  return out;
}
async function hkdf(salt, ikm, info, length) {
  const key = await crypto.subtle.importKey("raw", ikm, "HKDF", false, ["deriveBits"]);
  return new Uint8Array(await crypto.subtle.deriveBits({ name: "HKDF", hash: "SHA-256", salt, info }, key, length * 8));
}

async function vapidHeader(env, endpoint) {
  const jwk = JSON.parse(env.VAPID_PRIVATE_JWK);
  const key = await crypto.subtle.importKey("jwk", jwk, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const head = b64u(enc.encode(JSON.stringify({ typ: "JWT", alg: "ES256" })));
  const body = b64u(enc.encode(JSON.stringify({
    aud: new URL(endpoint).origin,
    exp: Math.floor(Date.now() / 1000) + 12 * 3600,
    sub: env.VAPID_SUBJECT
  })));
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, enc.encode(head + "." + body));
  return "vapid t=" + head + "." + body + "." + b64u(sig) + ", k=" + env.VAPID_PUBLIC;
}

async function encrypt(sub, payload) {
  const uaPublic = unb64u(sub.keys.p256dh);
  const authSecret = unb64u(sub.keys.auth);
  const ua = await crypto.subtle.importKey("raw", uaPublic, { name: "ECDH", namedCurve: "P-256" }, false, []);
  const as = await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"]);
  const asPublic = new Uint8Array(await crypto.subtle.exportKey("raw", as.publicKey));
  const shared = new Uint8Array(await crypto.subtle.deriveBits({ name: "ECDH", public: ua }, as.privateKey, 256));
  const ikm = await hkdf(authSecret, shared, concat(enc.encode("WebPush: info\0"), uaPublic, asPublic), 32);
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const cek = await hkdf(salt, ikm, enc.encode("Content-Encoding: aes128gcm\0"), 16);
  const nonce = await hkdf(salt, ikm, enc.encode("Content-Encoding: nonce\0"), 12);
  const aes = await crypto.subtle.importKey("raw", cek, "AES-GCM", false, ["encrypt"]);
  // One record: the payload, then the 0x02 delimiter that marks the last record.
  const data = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, aes, concat(enc.encode(payload), new Uint8Array([2]))));
  const rs = new Uint8Array([0, 0, 16, 0]); // record size 4096
  return concat(salt, rs, new Uint8Array([asPublic.length]), asPublic, data);
}

async function sendPush(env, sub, message) {
  const res = await fetch(sub.endpoint, {
    method: "POST",
    headers: {
      "Authorization": await vapidHeader(env, sub.endpoint),
      "Content-Encoding": "aes128gcm",
      "Content-Type": "application/octet-stream",
      "TTL": "3600",
      "Urgency": "high"
    },
    body: await encrypt(sub, JSON.stringify(message))
  });
  return res.status;
}
