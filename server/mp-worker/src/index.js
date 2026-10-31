// 빈두 멀티플레이 방 코드 중개.
// 게임은 /ws 에 WebSocket으로 붙는다. 방(Durable Object 하나)이 같은 방 사람끼리 WebRTC 연결 정보만 전해 주고,
// 게임 통신 자체는 WebRTC(직접 또는 Cloudflare TURN 중계)로 오가서 여기를 지나지 않는다.
// 약속은 tools/mp_signal.gd(로컬 시험 서버)와 같다.

const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const MAX_PLAYERS = 4;
const MAX_MSG = 64 * 1024;
const STUN = [{ urls: ["stun:stun.cloudflare.com:3478"] }];

function newCode() {
  const b = new Uint8Array(6);
  crypto.getRandomValues(b);
  let s = "";
  for (const x of b) s += CODE_CHARS[x % CODE_CHARS.length];
  return s;
}

function cleanCode(t) {
  return [...String(t || "").toUpperCase()].filter((c) => CODE_CHARS.includes(c)).join("").slice(0, 6);
}

// 방마다 TURN 임시 자격증명(24시간). 키가 없거나 실패하면 STUN만.
async function iceServers(env) {
  if (!env.TURN_KEY_ID || !env.TURN_KEY_TOKEN) return STUN;
  const base = `https://rtc.live.cloudflare.com/v1/turn/keys/${env.TURN_KEY_ID}/credentials`;
  const init = {
    method: "POST",
    headers: { Authorization: `Bearer ${env.TURN_KEY_TOKEN}`, "Content-Type": "application/json" },
    body: JSON.stringify({ ttl: 86400 }),
  };
  try {
    let r = await fetch(`${base}/generate-ice-servers`, init);
    if (!r.ok) r = await fetch(`${base}/generate`, init);
    if (!r.ok) return STUN;
    const j = await r.json();
    const list = Array.isArray(j.iceServers) ? j.iceServers : j.iceServers ? [j.iceServers] : [];
    return list.length ? list.map((s) => ({ ...s, urls: Array.isArray(s.urls) ? s.urls : [s.urls] })) : STUN;
  } catch {
    return STUN;
  }
}

// 멀티플레이 스위치: 대시보드(Workers > bindu-mp > 설정 > 변수)의 MP_OFF.
// 비어 있으면 켜짐, "hide"면 게임이 버튼을 숨김, 다른 글이면 버튼은 두고 그 글을 보여 주며 막음. 어느 쪽이든 새 방·참가는 거절.
function mpSwitch(env) {
  const off = String(env.MP_OFF || "").trim();
  if (!off) return { on: true };
  return off.toLowerCase() === "hide" ? { on: false, hide: true, msg: "" } : { on: false, hide: false, msg: off.slice(0, 120) };
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.pathname === "/health") return new Response("ok");
    if (url.pathname === "/status")
      return new Response(JSON.stringify(mpSwitch(env)), { headers: { "Content-Type": "application/json", "Cache-Control": "no-store" } });
    if (url.pathname !== "/ws") return new Response("bindu-mp", { status: 404 });
    if (req.headers.get("Upgrade") !== "websocket") return new Response("websocket only", { status: 426 });
    const sw = mpSwitch(env);
    if (!sw.on) return errSocket("off", { msg: sw.msg });
    const op = url.searchParams.get("op");
    if (op === "host") {
      // 겹치지 않는 코드가 나올 때까지 (32^6 ≈ 10억이라 거의 한 번)
      for (let i = 0; i < 5; i++) {
        const code = newCode();
        const stub = env.ROOMS.get(env.ROOMS.idFromName(code));
        const u = new URL(req.url);
        u.searchParams.set("code", code);
        const res = await stub.fetch(new Request(u, req));
        if (res.status !== 409) return res;
      }
      return new Response("busy", { status: 503 });
    }
    const code = cleanCode(url.searchParams.get("code"));
    if (code.length !== 6) return errSocket("nocode");
    const u = new URL(req.url);
    u.searchParams.set("code", code);
    return env.ROOMS.get(env.ROOMS.idFromName(code)).fetch(new Request(u, req));
  },
};

// 오류를 알리고 바로 닫는 WebSocket (게임은 HTTP 오류 코드를 못 읽어서).
function errSocket(code, extra = {}) {
  console.log(JSON.stringify({ ev: "err", code, ...extra }));
  const [client, server] = Object.values(new WebSocketPair());
  server.accept();
  server.send(JSON.stringify({ t: "err", code, ...extra }));
  server.close(1000, code);
  return new Response(null, { status: 101, webSocket: client });
}

export class Room {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
  }

  async fetch(req) {
    const url = new URL(req.url);
    const op = url.searchParams.get("op");
    const name = (url.searchParams.get("name") || "").slice(0, 16);
    const v = (url.searchParams.get("v") || "").slice(0, 20);
    let meta = await this.ctx.storage.get("meta");
    if (op === "host") {
      if (meta) return new Response("taken", { status: 409 });
      const mode = url.searchParams.get("mode") === "coop" ? "coop" : "vs";
      meta = { code: url.searchParams.get("code"), mode, v, next: 1, locked: false, created: Date.now(), ice: await iceServers(this.env) };
    } else {
      if (!meta) return errSocket("nocode");
      if (meta.v !== v) return errSocket("version", { host_v: meta.v });
      if (meta.locked) return errSocket("started");
      if (this.members().length >= MAX_PLAYERS) return errSocket("full");
    }
    const id = meta.next;
    meta.next += 1;
    await this.ctx.storage.put("meta", meta);
    // 1시간 뒤 방 정리 (판은 WebRTC로 계속되고, 여기는 들어오기·연결 맺기에만 쓰인다)
    await this.ctx.storage.setAlarm(Date.now() + 3600 * 1000);
    // 대시보드 Workers Logs(wrangler.toml observability)에 남는 방 기록. 이름은 "플랫폼 글자|닉네임"
    console.log(JSON.stringify({ ev: op === "host" ? "host" : "join", code: meta.code, mode: meta.mode, v, id, name,
      ice: meta.ice.map((x) => x.urls.length).join("+"), turn: meta.ice.some((x) => x.credential) }));

    const [client, server] = Object.values(new WebSocketPair());
    const peers = this.members().map((m) => ({ id: m.id, name: m.name }));
    for (const ws of this.ctx.getWebSockets()) this.sendTo(ws, { t: "join", id, name });
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment({ id, name });
    server.send(JSON.stringify({ t: "room", code: meta.code, id, mode: meta.mode, ice: meta.ice, peers }));
    return new Response(null, { status: 101, webSocket: client });
  }

  members() {
    return this.ctx.getWebSockets().map((ws) => ws.deserializeAttachment()).filter(Boolean);
  }

  sendTo(ws, obj) {
    try {
      ws.send(JSON.stringify(obj));
    } catch {}
  }

  async webSocketMessage(ws, data) {
    if (typeof data !== "string" || data.length > MAX_MSG) return;
    let j;
    try {
      j = JSON.parse(data);
    } catch {
      return;
    }
    const me = ws.deserializeAttachment();
    if (!me) return;
    if (j.t === "sig") {
      for (const other of this.ctx.getWebSockets()) {
        const a = other.deserializeAttachment();
        if (a && a.id === j.to) this.sendTo(other, { t: "sig", from: me.id, d: j.d });
      }
    } else if (j.t === "log" && typeof j.msg === "string") {
      // 게임이 연결 실패 진단을 남길 때 (방 코드와 함께 Workers Logs에)
      const meta = await this.ctx.storage.get("meta");
      console.log(JSON.stringify({ ev: "client", code: meta && meta.code, id: me.id, name: me.name, msg: j.msg.slice(0, 2000) }));
    } else if (j.t === "lock" && me.id === 1) {
      const meta = await this.ctx.storage.get("meta");
      if (meta) {
        meta.locked = true;
        await this.ctx.storage.put("meta", meta);
      }
    }
  }

  async webSocketClose(ws) {
    const me = ws.deserializeAttachment();
    if (!me) return;
    const rest = this.ctx.getWebSockets().filter((o) => o !== ws);
    if (me.id === 1) {
      // 호스트가 나가면 방이 끝난다
      for (const o of rest) {
        this.sendTo(o, { t: "closed" });
        try { o.close(1000, "closed"); } catch {}
      }
      await this.ctx.storage.deleteAll();
    } else {
      for (const o of rest) this.sendTo(o, { t: "leave", id: me.id });
    }
  }

  async webSocketError(ws) {
    await this.webSocketClose(ws);
  }

  async alarm() {
    for (const o of this.ctx.getWebSockets()) {
      try { o.close(1000, "expired"); } catch {}
    }
    await this.ctx.storage.deleteAll();
  }
}
