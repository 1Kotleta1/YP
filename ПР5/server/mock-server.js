#!/usr/bin/env node
/**
 * Учебный REST API «Кинотеки» для ПР5: данные из ПР4, вход по логину
 * и паролю, токены доступа и обновления, роли и проверка прав.
 *
 * Без внешних зависимостей: только модули http и crypto из Node.js.
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
const REFRESH_TTL = 7 * 24 * 3600;
// Ключ подписи токенов. По умолчанию новый при каждом запуске:
// после перезапуска сервера все выданные токены недействительны.
const SECRET = arg('secret', crypto.randomBytes(32).toString('hex'));

const THIS_YEAR = new Date().getFullYear();
const COLLECTIONS = ['movies', 'directors', 'genres', 'studios', 'viewers'];
const GENRE_CATEGORIES = ['Игровое кино', 'Анимация', 'Документальное'];
const TARIFFS = ['Базовый', 'Стандарт', 'Премиум'];
// Сколько посещений добавляет продление абонемента
const RENEW_VISITS = { Базовый: 4, Стандарт: 8, Премиум: 12 };

let db;
let nextId;
let refreshTokens; // jti → id пользователя; отозванный токен отсюда удаляется

function reset() {
  db = JSON.parse(fs.readFileSync(SEED, 'utf8'));
  nextId = {};
  for (const c of [...COLLECTIONS, 'users', 'visits']) {
    nextId[c] = db[c].reduce((m, e) => Math.max(m, e.id), 0) + 1;
  }
  refreshTokens = new Map();
}
reset();

// ---------------------------------------------------------------- ошибки

class HttpError extends Error {
  constructor(status, message, errors) {
    super(message);
    this.status = status;
    this.errors = errors;
  }
}

const notFound = (what, id) => new HttpError(404, `${what} с номером ${id} не найден(а).`);

function moviesWord(n) {
  const m10 = n % 10;
  const m100 = n % 100;
  if (m10 === 1 && m100 !== 11) return 'фильм';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'фильма';
  return 'фильмов';
}

// ---------------------------------------------------------------- описание сущностей

const lower = (s) => String(s ?? '').toLowerCase();
const byId = (c, id) => db[c].find((e) => e.id === id);
const alive = (c, id) => {
  const e = byId(c, id);
  return e && !e.deletedAt ? e : null;
};

/** Фильм отдаётся с развёрнутыми связями, а принимается с идентификаторами. */
function expandMovie(m) {
  const { studioId, directorIds, genreIds, ...rest } = m;
  const s = byId('studios', studioId);
  return {
    ...rest,
    studio: s ? { id: s.id, name: s.name, country: s.country } : null,
    directors: directorIds
      .map((id) => byId('directors', id))
      .filter(Boolean)
      .map((d) => ({ id: d.id, firstName: d.firstName, lastName: d.lastName })),
    genres: genreIds
      .map((id) => byId('genres', id))
      .filter(Boolean)
      .map((g) => ({ id: g.id, name: g.name })),
  };
}

const ENTITIES = {
  movies: {
    title: 'Фильм',
    sort: { title: (e) => lower(e.title), year: (e) => e.year, duration: (e) => e.duration, rating: (e) => e.rating },
    defaultSort: 'title',
    search: (e, q) => lower(e.title).includes(q) || lower(e.originalTitle).includes(q) || e.licenseNumber.includes(q),
    filter: (e, p) =>
      (!p.has('genreId') || e.genreIds.includes(Number(p.get('genreId')))) &&
      (!p.has('studioId') || e.studioId === Number(p.get('studioId'))) &&
      (!p.has('directorId') || e.directorIds.includes(Number(p.get('directorId')))) &&
      (!p.has('yearFrom') || e.year >= Number(p.get('yearFrom'))) &&
      (!p.has('yearTo') || e.year <= Number(p.get('yearTo'))),
    view: expandMovie,
    validate: validateMovie,
  },
  directors: {
    title: 'Режиссёр',
    sort: {
      lastName: (e) => lower(e.lastName),
      firstName: (e) => lower(e.firstName),
      birthYear: (e) => e.birthYear,
      country: (e) => lower(e.country),
    },
    defaultSort: 'lastName',
    search: (e, q) => lower(e.lastName).includes(q) || lower(e.firstName).includes(q) || lower(e.country).includes(q),
    filter: (e, p) => !p.has('country') || e.country === p.get('country'),
    validate: validateDirector,
    blockDelete: (ids, hard) => {
      if (!hard) return null;
      const used = db.movies.filter((m) => m.directorIds.some((id) => ids.includes(id)));
      return used.length
        ? `Нельзя удалить режиссёра навсегда: связанных фильмов — ${used.length}. Запись можно убрать в корзину.`
        : null;
    },
  },
  genres: {
    title: 'Жанр',
    sort: { name: (e) => lower(e.name), category: (e) => lower(`${e.category} ${e.name}`) },
    defaultSort: 'name',
    search: (e, q) => lower(e.name).includes(q) || lower(e.description).includes(q),
    filter: (e, p) => !p.has('category') || e.category === p.get('category'),
    validate: validateGenre,
    blockDelete: (ids, hard) => {
      if (!hard) return null;
      const used = db.movies.filter((m) => m.genreIds.some((id) => ids.includes(id)));
      return used.length
        ? `Нельзя удалить жанр навсегда: связанных фильмов — ${used.length}. Запись можно убрать в корзину.`
        : null;
    },
  },
  studios: {
    title: 'Киностудия',
    sort: {
      name: (e) => lower(e.name),
      country: (e) => lower(`${e.country} ${e.name}`),
      foundedYear: (e) => e.foundedYear,
    },
    defaultSort: 'name',
    search: (e, q) => lower(e.name).includes(q) || lower(e.country).includes(q),
    filter: (e, p) => !p.has('country') || e.country === p.get('country'),
    validate: validateStudio,
    // Один ко многим: студию нельзя удалить ни в корзину, ни навсегда
    blockDelete: (ids) => {
      const used = db.movies.filter((m) => ids.includes(m.studioId));
      if (!used.length) return null;
      const verb = used.length % 10 === 1 && used.length % 100 !== 11 ? 'ссылается' : 'ссылаются';
      return (
        `Нельзя удалить киностудию: на неё ${verb} ${used.length} ${moviesWord(used.length)} ` +
        `(например, «${used[0].title}»). Сначала укажите этим фильмам другую студию.`
      );
    },
  },
  viewers: {
    title: 'Зритель',
    sort: {
      lastName: (e) => lower(e.lastName),
      firstName: (e) => lower(e.firstName),
      email: (e) => lower(e.email),
      visitsLeft: (e) => e.card.visitsLeft,
    },
    defaultSort: 'lastName',
    search: (e, q) => lower(e.lastName).includes(q) || lower(e.email).includes(q) || lower(e.card.number).includes(q),
    filter: (e, p) => !p.has('tariff') || e.card.tariff === p.get('tariff'),
    validate: validateViewer,
  },
};

// ---------------------------------------------------------------- проверки (422)

const str = (v) => (typeof v === 'string' ? v.trim() : '');
const isInt = (v) => Number.isInteger(v);

function text(errors, body, key, max, label = 'Обязательное поле') {
  const v = str(body[key]);
  if (!v) errors[key] = label;
  else if (v.length > max) errors[key] = `Не длиннее ${max} символов`;
  return v;
}

function intIn(errors, key, v, min, max) {
  if (!isInt(v)) errors[key] = 'Введите целое число';
  else if (v < min || v > max) errors[key] = `Допустимо от ${min} до ${max}`;
  return v;
}

function idList(errors, key, v, collection, min, max, label) {
  if (!Array.isArray(v) || v.length < min) {
    errors[key] = label;
    return [];
  }
  if (v.length > max) errors[key] = `Не больше ${max}`;
  const missing = v.filter((id) => !alive(collection, id));
  if (missing.length) errors[key] = `Не найдены записи с номерами: ${missing.join(', ')}`;
  return [...new Set(v)];
}

function validateMovie(b, id) {
  const e = {};
  const out = {
    title: text(e, b, 'title', 100),
    originalTitle: text(e, b, 'originalTitle', 100),
    year: intIn(e, 'year', b.year, 1895, THIS_YEAR + 3),
    duration: intIn(e, 'duration', b.duration, 1, 600),
    rating: b.rating,
    licenseNumber: str(b.licenseNumber),
    studioId: b.studioId,
  };
  if (typeof b.rating !== 'number' || b.rating < 0 || b.rating > 10) e.rating = 'Допустимо от 0 до 10';
  if (!/^\d{9}$/.test(out.licenseNumber)) e.licenseNumber = 'Ровно 9 цифр';
  else if (db.movies.some((m) => m.licenseNumber === out.licenseNumber && m.id !== id)) {
    e.licenseNumber = 'Фильм с таким номером удостоверения уже есть в каталоге';
  }
  if (!isInt(b.studioId)) e.studioId = 'Выберите киностудию';
  else if (!alive('studios', b.studioId)) e.studioId = `Киностудия с номером ${b.studioId} не найдена`;
  out.directorIds = idList(e, 'directorIds', b.directorIds, 'directors', 1, 3, 'Выберите хотя бы одного режиссёра');
  out.genreIds = idList(e, 'genreIds', b.genreIds, 'genres', 1, 5, 'Выберите хотя бы один жанр');
  return [out, e];
}

const NAME_RE = /^[A-Za-zА-Яа-яЁё][A-Za-zА-Яа-яЁё' -]*$/;

function personName(e, b, key) {
  const v = text(e, b, key, 50);
  if (v && !e[key] && !NAME_RE.test(v)) e[key] = 'Только буквы, дефис и пробел';
  return v;
}

function validateDirector(b) {
  const e = {};
  const out = {
    lastName: personName(e, b, 'lastName'),
    firstName: personName(e, b, 'firstName'),
    country: text(e, b, 'country', 50),
    birthYear: intIn(e, 'birthYear', b.birthYear, 1850, THIS_YEAR - 10),
  };
  return [out, e];
}

function validateGenre(b, id) {
  const e = {};
  const out = {
    name: text(e, b, 'name', 30),
    category: str(b.category),
    description: str(b.description),
  };
  if (out.name && db.genres.some((g) => lower(g.name) === lower(out.name) && g.id !== id)) {
    e.name = 'Такой жанр уже есть';
  }
  if (!GENRE_CATEGORIES.includes(out.category)) e.category = 'Выберите категорию';
  if (out.description.length > 300) e.description = 'Не длиннее 300 символов';
  return [out, e];
}

function validateStudio(b) {
  const e = {};
  const out = {
    name: text(e, b, 'name', 60),
    country: text(e, b, 'country', 50),
    foundedYear: intIn(e, 'foundedYear', b.foundedYear, 1880, THIS_YEAR),
  };
  return [out, e];
}

function validateViewer(b, id) {
  const e = {};
  const card = b.card && typeof b.card === 'object' ? b.card : {};
  const out = {
    lastName: personName(e, b, 'lastName'),
    firstName: personName(e, b, 'firstName'),
    email: str(b.email),
    phone: str(b.phone),
    card: {
      number: str(card.number).toUpperCase(),
      tariff: str(card.tariff),
      visitsLeft: card.visitsLeft,
      issuedAt: str(card.issuedAt),
    },
  };
  if (!/^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[A-Za-zА-Яа-я]{2,}$/.test(out.email)) {
    e.email = 'Неверный адрес почты, пример: name@mail.ru';
  } else if (db.viewers.some((v) => lower(v.email) === lower(out.email) && v.id !== id)) {
    e.email = 'Зритель с такой почтой уже зарегистрирован';
  }
  if (out.phone && !/^\+7\d{10}$/.test(out.phone)) e.phone = 'Формат: +7 и 10 цифр';
  // Ключи ошибок вложенной карты — через точку, как путь к полю в JSON
  if (!/^KT-\d{6}$/.test(out.card.number)) e['card.number'] = 'Формат KT-123456';
  else if (db.viewers.some((v) => v.card.number === out.card.number && v.id !== id)) {
    e['card.number'] = 'Карта с таким номером уже выдана';
  }
  if (!TARIFFS.includes(out.card.tariff)) e['card.tariff'] = 'Выберите тариф';
  intIn(e, 'card.visitsLeft', out.card.visitsLeft, 0, 100);
  if (!/^\d{2}\.\d{2}\.\d{4}$/.test(out.card.issuedAt)) e['card.issuedAt'] = 'Формат ДД.ММ.ГГГГ';
  return [out, e];
}

// ---------------------------------------------------------------- роли и права

/**
 * Права ролей в разрезе операций. Та же таблица есть на клиенте
 * (lib/auth/permissions.dart), но там она только прячет кнопки,
 * а решение «разрешить» принимается здесь.
 */
const PERMISSIONS = {
  viewer: ['catalog.read', 'card.own'],
  manager: ['catalog.read', 'catalog.edit', 'viewers.manage', 'visits.mark'],
  admin: [
    'catalog.read', 'catalog.edit', 'viewers.manage',
    'trash.view', 'records.restore', 'records.hardDelete', 'users.manage', 'stats.view',
  ],
};
const ROLE_TITLES = { viewer: 'зритель', manager: 'менеджер', admin: 'администратор' };
const PERMISSION_TITLES = {
  'catalog.read': 'просмотр каталога',
  'catalog.edit': 'изменение каталога',
  'viewers.manage': 'работа со зрителями',
  'visits.mark': 'отметка посещений',
  'card.own': 'своя карта зрителя',
  'trash.view': 'просмотр корзины',
  'records.restore': 'восстановление записей',
  'records.hardDelete': 'удаление навсегда',
  'users.manage': 'управление пользователями',
  'stats.view': 'статистика',
};

function need(user, permission) {
  if (!PERMISSIONS[user.role].includes(permission)) {
    throw new HttpError(
      403,
      `Недостаточно прав: «${PERMISSION_TITLES[permission]}» не разрешено роли «${ROLE_TITLES[user.role]}».`,
    );
  }
}

// ---------------------------------------------------------------- пароли и токены

/** Пароль хранится только в виде scrypt-хеша с солью. */
function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  return `scrypt$${salt}$${crypto.scryptSync(password, salt, 32).toString('hex')}`;
}

function checkPassword(password, stored) {
  const [, salt, hash] = String(stored).split('$');
  if (!salt || !hash) return false;
  const actual = crypto.scryptSync(String(password), salt, 32);
  return crypto.timingSafeEqual(actual, Buffer.from(hash, 'hex'));
}

const b64 = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
const sig = (data) => crypto.createHmac('sha256', SECRET).update(data).digest('base64url');

/** Токен в формате JWT (HS256): заголовок.данные.подпись. */
function signToken(payload, ttl) {
  const now = Math.floor(Date.now() / 1000);
  const body = `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ ...payload, iat: now, exp: now + ttl })}`;
  return `${body}.${sig(body)}`;
}

function verifyToken(token, type) {
  const parts = String(token || '').split('.');
  if (parts.length !== 3) throw new HttpError(401, 'Требуется вход в систему.');
  const [header, payload, signature] = parts;
  const expected = Buffer.from(sig(`${header}.${payload}`));
  const actual = Buffer.from(signature);
  // Подпись не сходится — данные токена правили на клиенте
  if (expected.length !== actual.length || !crypto.timingSafeEqual(expected, actual)) {
    throw new HttpError(401, 'Подпись токена неверна.');
  }
  const data = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
  if (data.type !== type) throw new HttpError(401, 'Неверный тип токена.');
  if (data.exp < Math.floor(Date.now() / 1000)) throw new HttpError(401, 'Срок действия токена истёк.');
  const user = byId('users', data.sub);
  // Смена роли или блокировка увеличивает версию — старые токены перестают действовать
  if (!user || user.blocked || user.tokenVersion !== data.ver) {
    throw new HttpError(401, 'Сессия недействительна, войдите снова.');
  }
  return { data, user };
}

function publicUser(u) {
  return {
    id: u.id,
    username: u.username,
    firstName: u.firstName,
    lastName: u.lastName,
    role: u.role,
    viewerId: u.viewerId ?? null,
    blocked: !!u.blocked,
  };
}

/** Пара токенов. Роль кладётся в подписанный токен доступа. */
function issueTokens(user) {
  const jti = crypto.randomUUID();
  refreshTokens.set(jti, user.id);
  return {
    accessToken: signToken({ type: 'access', sub: user.id, role: user.role, ver: user.tokenVersion }, ACCESS_TTL),
    refreshToken: signToken({ type: 'refresh', sub: user.id, jti, ver: user.tokenVersion }, REFRESH_TTL),
    expiresIn: ACCESS_TTL,
    user: publicUser(user),
  };
}

/** Пользователь из заголовка Authorization: Bearer <токен доступа>. */
function authenticate(headers) {
  const m = /^Bearer (.+)$/.exec(headers.authorization || '');
  if (!m) throw new HttpError(401, 'Требуется вход в систему.');
  return verifyToken(m[1], 'access').user;
}

// ---------------------------------------------------------------- вход и регистрация

const LOGIN_RE = /^[a-z0-9_.-]{3,30}$/;

/** Требования к паролю — те же, что проверяет форма регистрации по мере ввода. */
function passwordProblems(password) {
  const p = String(password || '');
  const problems = [];
  if (p.length < 8) problems.push('не короче 8 символов');
  if (!/\d/.test(p)) problems.push('хотя бы одна цифра');
  if (!/[^A-Za-zА-Яа-яЁё0-9\s]/.test(p)) problems.push('хотя бы один специальный символ');
  return problems;
}

function login(body) {
  const username = str(body?.username).toLowerCase();
  const password = typeof body?.password === 'string' ? body.password : '';
  const errors = {};
  if (!username) errors.username = 'Введите логин';
  if (!password) errors.password = 'Введите пароль';
  if (Object.keys(errors).length) throw new HttpError(422, 'Ошибка валидации', errors);
  const user = db.users.find((u) => u.username === username);
  // Одинаковый ответ для «нет такого логина» и «неверный пароль»:
  // перебором нельзя выяснить, какие логины существуют
  if (!user || !checkPassword(password, user.passwordHash)) {
    throw new HttpError(401, 'Неверный логин или пароль.');
  }
  if (user.blocked) throw new HttpError(403, 'Учётная запись заблокирована. Обратитесь к администратору.');
  return issueTokens(user);
}

function nextCardNumber() {
  const max = db.viewers.reduce((m, v) => Math.max(m, Number(v.card.number.slice(3)) || 0), 100000);
  return `KT-${String(max + 1).padStart(6, '0')}`;
}

/** Регистрация доступна всем и всегда создаёт зрителя с новой картой. */
function register(body) {
  const b = body || {};
  const e = {};
  const username = str(b.username).toLowerCase();
  if (!LOGIN_RE.test(username)) e.username = 'От 3 до 30 символов: латинские буквы, цифры, точка, дефис, _';
  else if (db.users.some((u) => u.username === username)) e.username = 'Такой логин уже занят';
  const problems = passwordProblems(b.password);
  if (problems.length) e.password = `Пароль: ${problems.join(', ')}`;

  const today = new Date();
  const issuedAt = [today.getDate(), today.getMonth() + 1].map((n) => String(n).padStart(2, '0')).join('.') +
    `.${today.getFullYear()}`;
  const [viewer, viewerErrors] = validateViewer({
    lastName: b.lastName,
    firstName: b.firstName,
    email: b.email,
    phone: '',
    card: { number: nextCardNumber(), tariff: 'Базовый', visitsLeft: 4, issuedAt },
  });
  for (const key of ['lastName', 'firstName', 'email']) if (viewerErrors[key]) e[key] = viewerErrors[key];
  if (Object.keys(e).length) throw new HttpError(422, 'Ошибка валидации', e);

  const createdViewer = { id: nextId.viewers++, ...viewer, deletedAt: null };
  db.viewers.push(createdViewer);
  const user = {
    id: nextId.users++,
    username,
    passwordHash: hashPassword(b.password),
    firstName: viewer.firstName,
    lastName: viewer.lastName,
    role: 'viewer',
    viewerId: createdViewer.id,
    blocked: false,
    tokenVersion: 1,
  };
  db.users.push(user);
  return issueTokens(user);
}

/** Обновление пары токенов. Старый токен обновления отзывается. */
function refresh(body) {
  const { data, user } = verifyToken(body?.refreshToken, 'refresh');
  if (!refreshTokens.has(data.jti)) throw new HttpError(401, 'Токен обновления отозван, войдите снова.');
  refreshTokens.delete(data.jti);
  return issueTokens(user);
}

function logout(body) {
  try {
    const { data } = verifyToken(body?.refreshToken, 'refresh');
    refreshTokens.delete(data.jti);
  } catch {
    // Выход разрешён и с недействительным токеном
  }
}

// ---------------------------------------------------------------- своя карта, пользователи, статистика

function myCard(user) {
  const v = alive('viewers', user.viewerId);
  if (!v) throw new HttpError(404, 'Карта зрителя не найдена. Обратитесь к менеджеру кинотеки.');
  const history = db.visits
    .filter((x) => x.viewerId === v.id)
    .sort((a, b) => (a.at < b.at ? 1 : -1))
    .slice(0, 20);
  return { viewer: v, history };
}

function renewCard(user) {
  const { viewer } = myCard(user);
  const add = RENEW_VISITS[viewer.card.tariff] || 4;
  if (viewer.card.visitsLeft + add > 100) {
    throw new HttpError(409, `Абонемент уже продлён: на карте ${viewer.card.visitsLeft} посещений, больше 100 быть не может.`);
  }
  viewer.card.visitsLeft += add;
  db.visits.push({ id: nextId.visits++, viewerId: viewer.id, type: 'renew', delta: add, at: new Date().toISOString(), by: user.username });
  return myCard(user);
}

function updateUser(admin, id, body) {
  const u = byId('users', id);
  if (!u) throw notFound('Пользователь', id);
  if (u.id === admin.id) throw new HttpError(409, 'Нельзя изменить роль или заблокировать самого себя.');
  const errors = {};
  if (body?.role !== undefined && !PERMISSIONS[body.role]) errors.role = 'Неизвестная роль';
  if (body?.blocked !== undefined && typeof body.blocked !== 'boolean') errors.blocked = 'Ожидается true или false';
  if (Object.keys(errors).length) throw new HttpError(422, 'Ошибка валидации', errors);
  if (body.role !== undefined) u.role = body.role;
  if (body.blocked !== undefined) u.blocked = body.blocked;
  // Выданные токены перестают действовать: новая роль применяется сразу
  u.tokenVersion += 1;
  return publicUser(u);
}

function stats() {
  const count = (c) => ({
    total: db[c].filter((e) => !e.deletedAt).length,
    deleted: db[c].filter((e) => e.deletedAt).length,
  });
  const weekAgo = new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString();
  const visits = db.visits.filter((x) => x.type === 'visit');
  return {
    collections: Object.fromEntries(COLLECTIONS.map((c) => [c, count(c)])),
    users: Object.fromEntries(Object.keys(PERMISSIONS).map((r) => [r, db.users.filter((u) => u.role === r).length])),
    blockedUsers: db.users.filter((u) => u.blocked).length,
    visitsTotal: visits.length,
    visitsWeek: visits.filter((x) => x.at >= weekAgo).length,
    visitsLeft: db.viewers.filter((v) => !v.deletedAt).reduce((s, v) => s + v.card.visitsLeft, 0),
    activeSessions: refreshTokens.size,
  };
}

// ---------------------------------------------------------------- операции

function list(c, p) {
  const spec = ENTITIES[c];
  const includeDeleted = p.get('includeDeleted') === 'true';
  const q = lower(p.get('search') || '').trim();
  let rows = db[c].filter((e) => includeDeleted || !e.deletedAt);
  if (q) rows = rows.filter((e) => spec.search(e, q));
  rows = rows.filter((e) => spec.filter(e, p));

  const [field, dir] = (p.get('sort') || spec.defaultSort).split(',');
  const key = spec.sort[field] || spec.sort[spec.defaultSort];
  const sign = dir === 'desc' ? -1 : 1;
  rows.sort((a, b) => {
    const x = key(a);
    const y = key(b);
    return (x < y ? -1 : x > y ? 1 : a.id - b.id) * sign;
  });

  const size = Math.min(Math.max(Number(p.get('size')) || 10, 1), 100);
  const page = Math.max(Number(p.get('page')) || 1, 1);
  const items = rows.slice((page - 1) * size, page * size);
  return { items: items.map(spec.view || ((e) => e)), page, size, total: rows.length };
}

function getOne(c, id) {
  const e = byId(c, id);
  if (!e) throw notFound(ENTITIES[c].title, id);
  return (ENTITIES[c].view || ((x) => x))(e);
}

function save(c, body, id) {
  const spec = ENTITIES[c];
  const existing = id == null ? null : byId(c, id);
  if (id != null && !existing) throw notFound(spec.title, id);
  const [data, errors] = spec.validate(body || {}, id);
  if (Object.keys(errors).length) throw new HttpError(422, 'Ошибка валидации', errors);
  if (existing) {
    Object.assign(existing, data);
    return [200, getOne(c, id)];
  }
  const created = { id: nextId[c]++, ...data, deletedAt: null };
  db[c].push(created);
  return [201, getOne(c, created.id)];
}

function remove(c, ids, hard) {
  const spec = ENTITIES[c];
  const reason = spec.blockDelete && spec.blockDelete(ids, hard);
  if (reason) throw new HttpError(409, reason);
  let count = 0;
  if (hard) {
    const before = db[c].length;
    db[c] = db[c].filter((e) => !ids.includes(e.id));
    count = before - db[c].length;
  } else {
    const now = new Date().toISOString();
    for (const e of db[c]) {
      if (ids.includes(e.id) && !e.deletedAt) {
        e.deletedAt = now;
        count++;
      }
    }
  }
  return count;
}

/** Каскад формы фильма: какие режиссёры уже работали с какой студией. */
function studioDirectors() {
  const out = {};
  for (const m of db.movies) {
    if (m.deletedAt) continue;
    out[m.studioId] = [...new Set([...(out[m.studioId] || []), ...m.directorIds])];
  }
  return out;
}

/** Отметка посещения по карте зрителя: 409, если посещений не осталось. */
function visit(id, user) {
  const v = byId('viewers', id);
  if (!v) throw notFound('Зритель', id);
  if (v.deletedAt) throw new HttpError(409, `Зритель «${v.firstName} ${v.lastName}» в корзине — посещение отметить нельзя.`);
  if (v.card.visitsLeft <= 0) {
    throw new HttpError(
      409,
      `По карте ${v.card.number} не осталось посещений. Продлите тариф «${v.card.tariff}», чтобы пропустить зрителя.`,
    );
  }
  v.card.visitsLeft -= 1;
  db.visits.push({ id: nextId.visits++, viewerId: v.id, type: 'visit', delta: -1, at: new Date().toISOString(), by: user.username });
  return v;
}

// ---------------------------------------------------------------- маршрутизация

const notAddress = (parts) => new HttpError(404, `Нет такого адреса: /api/${parts.join('/')}`);

async function route(method, parts, p, body, headers, who) {
  // parts — путь после /api, например ['movies', '7', 'restore']
  const [head, second, third, fourth] = parts;

  if (head === '__health' && method === 'GET') {
    const counts = Object.fromEntries([...COLLECTIONS, 'users'].map((c) => [c, db[c].length]));
    return [200, { status: 'ok', time: new Date().toISOString(), accessTtl: ACCESS_TTL, counts }];
  }
  if (head === '__reset' && method === 'POST') {
    reset();
    return [200, { status: 'reset' }];
  }

  // Открытые адреса: вход, регистрация, обновление токена, выход
  if (head === 'auth' && method === 'POST' && !third) {
    if (second === 'login') return [200, login(body)];
    if (second === 'register') return [201, register(body)];
    if (second === 'refresh') return [200, refresh(body)];
    if (second === 'logout') {
      logout(body);
      return [204, null];
    }
  }

  // Всё остальное — только с действующим токеном доступа
  const user = authenticate(headers);
  who.user = user;

  if (head === 'auth' && second === 'me' && method === 'GET' && !third) return [200, publicUser(user)];

  if (head === 'me' && second === 'card' && !fourth) {
    need(user, 'card.own');
    if (!third && method === 'GET') return [200, myCard(user)];
    if (third === 'renew' && method === 'POST') return [200, renewCard(user)];
  }

  if (head === 'users') {
    need(user, 'users.manage');
    if (!second && method === 'GET') return [200, db.users.map(publicUser)];
    const id = Number(second);
    if (isInt(id) && !third && method === 'PUT') return [200, updateUser(user, id, body)];
    throw notAddress(parts);
  }

  if (head === 'stats' && !second && method === 'GET') {
    need(user, 'stats.view');
    return [200, stats()];
  }

  if (head === 'studio-directors' && method === 'GET' && !second) {
    need(user, 'catalog.read');
    return [200, studioDirectors()];
  }

  if (!COLLECTIONS.includes(head)) throw notAddress(parts);
  const c = head;
  // Зрители — персональные данные: их видят только менеджер и администратор
  const readPerm = c === 'viewers' ? 'viewers.manage' : 'catalog.read';
  const writePerm = c === 'viewers' ? 'viewers.manage' : 'catalog.edit';

  if (!second) {
    if (method === 'GET') {
      need(user, readPerm);
      if (p.get('includeDeleted') === 'true') need(user, 'trash.view');
      return [200, list(c, p)];
    }
    if (method === 'POST') {
      need(user, writePerm);
      return save(c, body);
    }
  }
  if (second === 'all' && method === 'GET' && !third) {
    // Справочники для подписей: удалённые записи тоже нужны, чтобы показать название
    need(user, readPerm);
    const includeDeleted = p.get('includeDeleted') === 'true';
    const view = ENTITIES[c].view || ((e) => e);
    return [200, db[c].filter((e) => includeDeleted || !e.deletedAt).map(view)];
  }
  if (second === 'bulk-delete' && method === 'POST') {
    need(user, body?.hard === true ? 'records.hardDelete' : writePerm);
    const ids = Array.isArray(body?.ids) ? body.ids.filter(isInt) : [];
    if (!ids.length) throw new HttpError(422, 'Ошибка валидации', { ids: 'Не выбрано ни одной записи' });
    return [200, { deleted: remove(c, ids, body.hard === true) }];
  }

  const id = Number(second);
  if (!isInt(id)) throw notAddress(parts);

  if (!third) {
    if (method === 'GET') {
      need(user, readPerm);
      return [200, getOne(c, id)];
    }
    if (method === 'PUT') {
      need(user, writePerm);
      return save(c, body, id);
    }
    if (method === 'DELETE') {
      const hard = p.get('hard') === 'true';
      need(user, hard ? 'records.hardDelete' : writePerm);
      if (!byId(c, id)) throw notFound(ENTITIES[c].title, id);
      remove(c, [id], hard);
      return [204, null];
    }
  }
  if (third === 'restore' && method === 'POST') {
    need(user, 'records.restore');
    const e = byId(c, id);
    if (!e) throw notFound(ENTITIES[c].title, id);
    e.deletedAt = null;
    return [200, getOne(c, id)];
  }
  if (c === 'viewers' && third === 'visit' && method === 'POST') {
    need(user, 'visits.mark');
    return [200, visit(id, user)];
  }

  throw new HttpError(405, `Метод ${method} не поддерживается для /api/${parts.join('/')}`);
}

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
        reject(new HttpError(400, 'Тело запроса — не JSON'));
      }
    });
    req.on('error', reject);
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const server = http.createServer(async (req, res) => {
  const started = Date.now();
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const origin = req.headers.origin;
  const cors = corsHeaders(origin);
  const who = { user: null };
  let status = 500;

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
    if (!url.pathname.startsWith('/api')) throw new HttpError(404, 'Адреса API начинаются с /api');

    // Служебные параметры для проверки клиента
    const delay = Number(url.searchParams.get('__delay'));
    if (delay > 0) await sleep(Math.min(delay, 30000));
    const fail = Number(url.searchParams.get('__fail'));
    if (fail >= 400 && fail <= 599) {
      throw new HttpError(fail, `Имитация ошибки сервера (__fail=${fail})`);
    }

    const parts = url.pathname.replace(/^\/api\/?/, '').split('/').filter(Boolean);
    const body = ['POST', 'PUT'].includes(req.method) ? await readBody(req) : undefined;
    const [code, payload] = await route(req.method, parts, url.searchParams, body, req.headers, who);
    send(code, payload);
  } catch (err) {
    if (err instanceof HttpError) {
      send(err.status, { message: err.message, ...(err.errors ? { errors: err.errors } : {}) });
    } else {
      console.error(err);
      send(500, { message: 'Внутренняя ошибка сервера' });
    }
  } finally {
    if (!QUIET) {
      const blocked = origin && !cors['Access-Control-Allow-Origin'] ? `  [CORS: источник ${origin} не разрешён]` : '';
      const by = who.user ? `  [${who.user.username}: ${who.user.role}]` : '';
      console.log(`${req.method.padEnd(7)} ${url.pathname}${url.search} -> ${status} (${Date.now() - started} мс)${by}${blocked}`);
    }
  }
});

server.listen(PORT, () => {
  console.log(`Учебный API «Кинотеки»: http://localhost:${PORT}/api`);
  console.log(`Разрешённые источники (CORS): ${ORIGINS.join(', ')}`);
  console.log(`Срок жизни токена доступа: ${ACCESS_TTL} с, токена обновления: ${REFRESH_TTL / 86400} дней`);
  console.log(`Проверка: http://localhost:${PORT}/api/__health`);
});
