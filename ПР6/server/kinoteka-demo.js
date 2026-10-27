/**
 * Демонстрационный режим опубликованной сборки (API_BASE_URL=demo).
 *
 * GitHub Pages отдаёт только статические файлы по HTTPS, а учебный сервер
 * работает по HTTP на компьютере разработчика: браузер не пустит страницу
 * с HTTPS к такому API (смешанное содержимое). Поэтому опубликованная сборка
 * выполняет api-core.js прямо в браузере. Логика, проверки, роли и коды
 * ответов те же, что у mock-server.js; данные хранятся в localStorage.
 *
 * Клиент обращается сюда через DemoAdapter (lib/core/demo_adapter_web.dart):
 *   window.kinotekaDemo.handle(method, url, headersJson, body) → Promise<JSON>
 */
(function () {
  'use strict';

  const STATE_KEY = 'kinoteka_demo_state_v1';
  const BASE = document.currentScript ? document.currentScript.src.replace(/[^/]*$/, '') : 'demo/';

  // Пароли учебных учётных записей опубликованы в README и на экране входа.
  // В seed.json они лежат scrypt-хешами, которые браузер проверить не может,
  // поэтому при первом запуске хеши пересчитываются браузерным алгоритмом.
  const DEMO_PASSWORDS = {
    admin: 'Admin#2026',
    manager: 'Manager#2026',
    viewer: 'Viewer#2026',
    viewer2: 'Viewer#2026',
    blocked: 'Blocked#2026',
  };

  // ---------------------------------------------------------------- SHA-256 и HMAC

  // WebCrypto асинхронный, а api-core.js проверяет подпись синхронно,
  // поэтому здесь короткая синхронная реализация SHA-256 (FIPS 180-4).
  const K = new Uint32Array([
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ]);

  function sha256(bytes) {
    const h = new Uint32Array([0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]);
    const len = bytes.length;
    const padded = new Uint8Array(((len + 9 + 63) >> 6) << 6);
    padded.set(bytes);
    padded[len] = 0x80;
    const view = new DataView(padded.buffer);
    view.setUint32(padded.length - 4, len * 8);
    view.setUint32(padded.length - 8, Math.floor(len / 0x20000000));
    const w = new Uint32Array(64);
    const rotr = (x, n) => (x >>> n) | (x << (32 - n));
    for (let off = 0; off < padded.length; off += 64) {
      for (let i = 0; i < 16; i++) w[i] = view.getUint32(off + i * 4);
      for (let i = 16; i < 64; i++) {
        const s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
        const s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) | 0;
      }
      let [a, b, c, d, e, f, g, k] = h;
      for (let i = 0; i < 64; i++) {
        const t1 = (k + (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) + ((e & f) ^ (~e & g)) + K[i] + w[i]) | 0;
        const t2 = ((rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) + ((a & b) ^ (a & c) ^ (b & c))) | 0;
        k = g; g = f; f = e; e = (d + t1) | 0; d = c; c = b; b = a; a = (t1 + t2) | 0;
      }
      h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += k;
    }
    const out = new Uint8Array(32);
    const ov = new DataView(out.buffer);
    h.forEach((x, i) => ov.setUint32(i * 4, x));
    return out;
  }

  const utf8 = (text) => new TextEncoder().encode(text);
  const hex = (bytes) => Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');

  function hmacSha256(key, data) {
    let k = utf8(key);
    if (k.length > 64) k = sha256(k);
    const block = new Uint8Array(64);
    block.set(k);
    const msg = utf8(data);
    const inner = new Uint8Array(64 + msg.length);
    inner.set(block.map((b) => b ^ 0x36));
    inner.set(msg, 64);
    const outer = new Uint8Array(64 + 32);
    outer.set(block.map((b) => b ^ 0x5c));
    outer.set(sha256(inner), 64);
    return bytesToBase64Url(sha256(outer));
  }

  function bytesToBase64Url(bytes) {
    let s = '';
    bytes.forEach((b) => (s += String.fromCharCode(b)));
    return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  function fromBase64Url(text) {
    const b64 = text.replace(/-/g, '+').replace(/_/g, '/');
    const bin = atob(b64 + '='.repeat((4 - (b64.length % 4)) % 4));
    return new TextDecoder().decode(Uint8Array.from(bin, (c) => c.charCodeAt(0)));
  }

  function randomHex(n) {
    return hex(crypto.getRandomValues(new Uint8Array(n)));
  }

  /** Хеш пароля в браузере: SHA-256 с солью, 2000 раундов. */
  function hashPassword(password, salt = randomHex(16)) {
    let h = utf8(salt + password);
    for (let i = 0; i < 2000; i++) h = sha256(h);
    return `sha256$${salt}$${hex(h)}`;
  }

  const browserCrypto = {
    hashPassword: (password) => hashPassword(password),
    checkPassword(password, stored) {
      const [kind, salt] = stored.split('$');
      return kind === 'sha256' && !!salt && hashPassword(password, salt) === stored;
    },
    hmacSha256,
    safeEqual: (a, b) => a.length === b.length && a === b,
    toBase64Url: (text) => bytesToBase64Url(utf8(text)),
    fromBase64Url,
    randomId: () => (crypto.randomUUID ? crypto.randomUUID() : randomHex(16)),
  };

  // ---------------------------------------------------------------- состояние

  function loadState() {
    try {
      return JSON.parse(localStorage.getItem(STATE_KEY));
    } catch (_) {
      return null;
    }
  }

  let ready = null;
  let api = null;

  function init() {
    ready ??= (async () => {
      const saved = loadState();
      const seed = await (await fetch(BASE + 'seed.json')).json();
      for (const u of seed.users) {
        if (DEMO_PASSWORDS[u.username]) u.passwordHash = hashPassword(DEMO_PASSWORDS[u.username]);
      }
      // Ключ подписи сохраняется: после перезагрузки страницы токены остаются действительными
      const secret = (saved && saved.secret) || randomHex(32);
      api = window.KinotekaApi.createApi({ seed, secret, crypto: browserCrypto });
      if (saved && saved.state) api.restore(saved.state);
      persist(secret);
      api.secret = secret;
    })();
    return ready;
  }

  function persist(secret) {
    try {
      localStorage.setItem(STATE_KEY, JSON.stringify({ secret, state: api.snapshot() }));
    } catch (_) {
      // Хранилище переполнено или запрещено — работа продолжается в памяти
    }
  }

  // ---------------------------------------------------------------- запрос

  async function handle(method, url, headersJson, body) {
    await init();
    const u = new URL(url, location.href);
    const headers = {};
    for (const [k, v] of Object.entries(JSON.parse(headersJson || '{}'))) headers[k.toLowerCase()] = String(v);
    let data;
    if (body) {
      try {
        data = JSON.parse(body);
      } catch (_) {
        return JSON.stringify({ status: 400, body: { message: 'Тело запроса — не JSON' } });
      }
    }
    const result = await api.handle(method, u.pathname.replace(/^.*?\/api(\/|$)/, '/api$1'), u.searchParams, data, headers);
    if (method !== 'GET') persist(api.secret);
    const who = result.user ? `  [${result.user.username}: ${result.user.role}]` : '';
    console.debug(`[demo-api] ${method} ${u.pathname}${u.search} -> ${result.status}${who}`);
    return JSON.stringify({ status: result.status, body: result.payload ?? null });
  }

  function reset() {
    localStorage.removeItem(STATE_KEY);
    ready = null;
  }

  window.kinotekaDemo = { handle, reset };
})();
