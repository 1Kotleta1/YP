import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_exceptions.dart';
import '../core/config.dart';
import '../models/app_user.dart';
import 'auth_api.dart';
import 'permissions.dart';

/// Почему пользователь вышел из системы — текст показывается на экране входа.
enum LogoutReason {
  manual(null),
  expired('Сессия истекла: обновить токен не удалось. Войдите снова.'),
  inactivity('Сессия завершена: вы не работали с приложением более трёх минут.'),
  sessionLimit('Сессия завершена: истекло наибольшее время работы без повторного входа.');

  const LogoutReason(this.message);

  final String? message;
}

/// Сессия пользователя: токены, текущий пользователь, сроки.
///
/// Токен доступа живёт недолго (15 минут), токен обновления — неделю.
/// Оба должны пережить перезагрузку страницы, поэтому лежат
/// в shared_preferences, то есть в localStorage браузера.
class AuthNotifier extends ChangeNotifier {
  AuthNotifier(
    this._prefs,
    this._api, {
    DateTime Function()? clock,
    this.maxSession = sessionMaxDuration,
    this.idleTimeout = inactivityTimeout,
  }) : _now = clock ?? DateTime.now;

  static const kAccess = 'auth_access_token';
  static const kRefresh = 'auth_refresh_token';
  static const kUser = 'auth_user';
  static const kStarted = 'auth_session_started';
  static const kActivity = 'auth_last_activity';

  final SharedPreferences _prefs;
  final AuthApi _api;
  final DateTime Function() _now;
  final Duration maxSession;
  final Duration idleTimeout;

  AppUser? _user;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _startedAt;
  LogoutReason? _lastReason;
  Timer? _sessionTimer;
  Future<void>? _refreshing;

  /// Сколько раз за сессию обновлялся токен — видно в меню пользователя.
  int refreshCount = 0;

  AppUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _user != null;
  Role? get role => _user?.role;

  /// Причина последнего выхода; сбрасывается после показа.
  LogoutReason? get lastReason => _lastReason;
  void clearReason() => _lastReason = null;

  /// Когда сессия закончится независимо от активности.
  DateTime? get sessionEndsAt => _startedAt?.add(maxSession);

  bool can(Permission permission) => roleCan(_user?.role, permission);

  /// Восстановление сессии при запуске приложения.
  /// Вызывается один раз до построения дерева виджетов.
  Future<void> restore() async {
    final access = _prefs.getString(kAccess);
    final refresh = _prefs.getString(kRefresh);
    if (access == null || refresh == null) return;

    final started = DateTime.fromMillisecondsSinceEpoch(_prefs.getInt(kStarted) ?? 0);
    final activity = DateTime.fromMillisecondsSinceEpoch(_prefs.getInt(kActivity) ?? 0);
    final now = _now();
    // Неактивность и предельный срок проверяются и через перезагрузку страницы
    if (now.difference(started) >= maxSession) return _endSilently(LogoutReason.sessionLimit);
    if (now.difference(activity) >= idleTimeout) return _endSilently(LogoutReason.inactivity);

    _accessToken = access;
    _refreshToken = refresh;
    _startedAt = started;
    _user = _cachedUser();

    try {
      if (_user == null) {
        _user = await _api.me(access);
        await _prefs.setString(kUser, jsonEncode(_user!.toJson()));
      }
      // Токен доступа уже истёк — обновляем сразу, не дожидаясь ответа 401
      if (tokenExpired(access, now)) await refreshTokens();
    } on UnauthorizedException {
      return _endSilently(LogoutReason.expired);
    } on ApiException {
      // Сервер недоступен: сессию не сбрасываем, экраны покажут ошибку
    }
    _scheduleSessionEnd();
    notifyListeners();
  }

  /// Профиль из localStorage — только для того, чтобы нарисовать интерфейс.
  /// Разрешение на операцию выдаёт сервер по роли из подписанного токена.
  AppUser? _cachedUser() {
    final raw = _prefs.getString(kUser);
    if (raw == null) return null;
    try {
      return AppUser.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> login(String username, String password) async {
    await _start(await _api.login(username, password));
  }

  Future<void> register({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    await _start(await _api.register(
      username: username,
      password: password,
      firstName: firstName,
      lastName: lastName,
      email: email,
    ));
  }

  Future<void> _start(AuthSession s) async {
    _startedAt = _now();
    _lastReason = null;
    refreshCount = 0;
    await _save(s);
    await _prefs.setInt(kStarted, _startedAt!.millisecondsSinceEpoch);
    await touch(force: true);
    _scheduleSessionEnd();
    notifyListeners();
  }

  Future<void> _save(AuthSession s) async {
    _accessToken = s.accessToken;
    _refreshToken = s.refreshToken;
    _user = s.user;
    await _prefs.setString(kAccess, s.accessToken);
    await _prefs.setString(kRefresh, s.refreshToken);
    await _prefs.setString(kUser, jsonEncode(s.user.toJson()));
  }

  /// Обновление пары токенов.
  ///
  /// Несколько запросов могут получить 401 одновременно — обновление при
  /// этом выполняется один раз, остальные ждут его результата. Если сервер
  /// отказал (401), пользователь выходит из системы, а не уходит в цикл.
  Future<void> refreshTokens() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _doRefresh() async {
    final token = _refreshToken;
    if (token == null) throw const UnauthorizedException();
    try {
      await _save(await _api.refresh(token));
      refreshCount++;
      notifyListeners();
    } on UnauthorizedException {
      await logout(reason: LogoutReason.expired);
      rethrow;
    }
  }

  /// Отметка действия пользователя для проверки неактивности через
  /// перезагрузку страницы. Пишется не чаще раза в пять секунд.
  Future<void> touch({bool force = false}) async {
    final now = _now().millisecondsSinceEpoch;
    final last = _prefs.getInt(kActivity) ?? 0;
    if (force || now - last > 5000) await _prefs.setInt(kActivity, now);
  }

  void _scheduleSessionEnd() {
    _sessionTimer?.cancel();
    final ends = sessionEndsAt;
    if (ends == null) return;
    final left = ends.difference(_now());
    _sessionTimer = Timer(left.isNegative ? Duration.zero : left, () => logout(reason: LogoutReason.sessionLimit));
  }

  Future<void> logout({LogoutReason reason = LogoutReason.manual}) async {
    if (_user == null && _accessToken == null) return;
    final refresh = _refreshToken;
    if (refresh != null) unawaited(_api.logout(refresh));
    await _endSilently(reason);
    notifyListeners();
  }

  Future<void> _endSilently(LogoutReason reason) async {
    _sessionTimer?.cancel();
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _startedAt = null;
    _lastReason = reason == LogoutReason.manual ? null : reason;
    for (final k in [kAccess, kRefresh, kUser, kStarted, kActivity]) {
      await _prefs.remove(k);
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
}

/// Срок действия из полезной нагрузки JWT. Подпись здесь не проверяется
/// и проверяться не может: ключ есть только у сервера.
bool tokenExpired(String token, DateTime now) {
  try {
    final payload = token.split('.')[1];
    final data = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload)))) as Map;
    final exp = data['exp'] as int;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000).isBefore(now);
  } catch (_) {
    return true;
  }
}
