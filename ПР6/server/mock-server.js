#!/usr/bin/env node
/**
 * Учебный REST API «Кинотеки»: HTTP-обёртка над api-core.js.
 * Данные из ПР4, вход по логину и паролю, токены, роли и проверка прав (ПР5).
 *
 * Без внешних зависимостей: только модули http и crypto из Node.js.
 * Логика API вынесена в api-core.js — тот же файл работает в браузере
 * в демонстрационном режиме опубликованной сборки (ПР6).
 * Данные живут в памяти и при перезапуске сервера возвращаются
 * к начальному набору из seed.json.
 *
 *   node mock-server.js --port 8080 --origin http://localhost:5555 --ttl 900
 *
 * Описание адресов и форматов — в api/КОНТРАКТ-API.md.
 */
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { URL } = require('url');
const { createApi } = require('./api-core');

// ---------------------------------------------------------------- параметры

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

const PORT = Number(arg('port', 8080));
// Разрешённые источники через запятую. Сервер намеренно строгий:
// с другого порта браузер получит ошибку CORS.
const ORIGINS = arg('origin', 'http://localhost:5555').split(',').map((s) => s.trim());
const SEED = arg('seed', path.join(__dirname, 'seed.json'));
const QUIET = process.argv.includes('--quiet');
// Срок жизни токена доступа в секундах. Для проверки обновления токена
// сервер запускают с коротким сроком: --ttl 60.
const ACCESS_TTL = Number(arg('ttl', 900));
// Ключ подписи токенов. По умолчанию новый при каждом запуске:
// после перезапуска сервера все выданные токены недействительны.
const SECRET = arg('secret', crypto.randomBytes(32).toString('hex'));

// Криптография Node.js для api-core.js
const nodeCrypto = {
  /** Пароль хранится только в виде scrypt-хеша с солью. */
  hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
    return `scrypt$${salt}$${crypto.scryptSync(password, salt, 32).toString('hex')}`;
  },
  checkPassword(password, stored) {
    const [, salt, hash] = stored.split('$');
    if (!salt || !hash) return false;
    const actual = crypto.scryptSync(password, salt, 32);
    return crypto.timingSafeEqual(actual, Buffer.from(hash, 'hex'));
  },
  hmacSha256: (key, data) => crypto.createHmac('sha256', key).update(data).digest('base64url'),
  safeEqual(a, b) {
    const x = Buffer.from(a);
    const y = Buffer.from(b);
    return x.length === y.length && crypto.timingSafeEqual(x, y);
  },
  toBase64Url: (text) => Buffer.from(text).toString('base64url'),
  fromBase64Url: (text) => Buffer.from(text, 'base64url').toString('utf8'),
  randomId: () => crypto.randomUUID(),
};

const api = createApi({
  seed: JSON.parse(fs.readFileSync(SEED, 'utf8')),
  accessTtl: ACCESS_TTL,
  secret: SECRET,
  crypto: nodeCrypto,
});

// ---------------------------------------------------------------- HTTP

function corsHeaders(origin) {
  if (!origin || !ORIGINS.includes(origin)) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '600',
    Vary: 'Origin',
  };
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.setEncoding('utf8');
    req.on('data', (chunk) => (raw += chunk));
    req.on('end', () => {
      if (!raw) return resolve(undefined);
      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(new api.HttpError(400, 'Тело запроса — не JSON'));
      }
    });
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  const started = Date.now();
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const origin = req.headers.origin;
  const cors = corsHeaders(origin);
  let status = 500;
  let user = null;

  const send = (code, payload) => {
    status = code;
    const headers = { ...cors };
    if (payload !== null && payload !== undefined) headers['Content-Type'] = 'application/json; charset=utf-8';
    res.writeHead(code, headers);
    res.end(payload === null || payload === undefined ? undefined : JSON.stringify(payload));
  };

  try {
    if (req.method === 'OPTIONS') {
      // Предварительный запрос CORS: без него браузер не отправит POST/PUT/DELETE
      send(origin && !cors['Access-Control-Allow-Origin'] ? 403 : 204, null);
      return;
    }
    const body = ['POST', 'PUT'].includes(req.method) ? await readBody(req) : undefined;
    const result = await api.handle(req.method, url.pathname, url.searchParams, body, req.headers);
    user = result.user;
    send(result.status, result.payload);
  } catch (err) {
    if (err instanceof api.HttpError) {
      send(err.status, { message: err.message });
    } else {
      console.error(err);
      send(500, { message: 'Внутренняя ошибка сервера' });
    }
  } finally {
    if (!QUIET) {
      const blocked = origin && !cors['Access-Control-Allow-Origin'] ? `  [CORS: источник ${origin} не разрешён]` : '';
      const by = user ? `  [${user.username}: ${user.role}]` : '';
      console.log(`${req.method.padEnd(7)} ${url.pathname}${url.search} -> ${status} (${Date.now() - started} мс)${by}${blocked}`);
    }
  }
});

server.listen(PORT, () => {
  console.log(`Учебный API «Кинотеки»: http://localhost:${PORT}/api`);
  console.log(`Разрешённые источники (CORS): ${ORIGINS.join(', ')}`);
  console.log(`Срок жизни токена доступа: ${api.accessTtl} с, токена обновления: ${api.refreshTtl / 86400} дней`);
  console.log(`Проверка: http://localhost:${PORT}/api/__health`);
});
