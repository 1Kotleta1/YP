import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinoteka/auth/auth_api.dart';
import 'package:kinoteka/auth/auth_notifier.dart';
import 'package:kinoteka/auth/permissions.dart';
import 'package:kinoteka/core/api_client.dart';
import 'package:kinoteka/core/api_exceptions.dart';
import 'package:kinoteka/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Подменённый транспорт: сервер имитируется функцией.
class FakeServer implements HttpClientAdapter {
  FakeServer(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions o) handler;
  final List<String> log = [];
  final List<RequestOptions> requests = [];

  int count(String entry) => log.where((l) => l == entry).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final grant = o.queryParameters['grant_type'];
    log.add('${o.method} ${o.path}${grant == null ? '' : '?$grant'}');
    requests.add(o);
    return handler(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Object? body) => ResponseBody.fromString(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json; charset=utf-8'],
  },
);

const loginEmail = 'POST /rest/v1/rpc/login_email';
const signIn = 'POST /auth/v1/token?password';
const refreshCall = 'POST /auth/v1/token?refresh_token';
const profileCall = 'GET /rest/v1/profiles';

/// JWT Supabase Auth: sub — идентификатор пользователя в auth.users.
/// Подпись клиенту не важна.
String token(String sub, DateTime exp) {
  String part(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final payload = {'sub': sub, 'role': 'authenticated', 'exp': exp.millisecondsSinceEpoch ~/ 1000};
  return '${part({'alg': 'HS256'})}.${part(payload)}.sig';
}

/// Ответ /auth/v1/token и /auth/v1/signup.
Map<String, dynamic> session(String role, {String suffix = '1'}) => {
  'access_token': token('uid-$role', DateTime.now().add(const Duration(hours: 1))) + suffix,
  'refresh_token': 'refresh-$suffix',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {'id': 'uid-$role'},
};

/// Строка таблицы profiles.
Map<String, dynamic> profileRow(String role, {bool blocked = false}) => {
  'id': 3,
  'auth_id': 'uid-$role',
  'username': role,
  'email': '$role@kinoteka.test',
  'first_name': 'Алексей',
  'last_name': 'Иванов',
  'role': role,
  'viewer_id': role == 'viewer' ? 1 : null,
  'blocked': blocked,
};

/// Supabase в миниатюре: функция login_email, вход, обновление токена,
/// профиль и выход. Токен после обновления оканчивается на «2».
Future<ResponseBody> Function(RequestOptions) supabase(
  String role, {
  bool blocked = false,
  Duration refreshDelay = Duration.zero,
}) => (o) async {
  final grant = o.queryParameters['grant_type'];
  if (grant == 'refresh_token') await Future<void>.delayed(refreshDelay);
  return switch (o.path) {
    '/rest/v1/rpc/login_email' => json(200, '$role@kinoteka.test'),
    '/auth/v1/token' => json(200, session(role, suffix: grant == 'refresh_token' ? '2' : '1')),
    '/rest/v1/profiles' => json(200, [profileRow(role, blocked: blocked)]),
    '/auth/v1/logout' => json(204, null),
    _ => json(404, {'code': 'PGRST205', 'message': 'not found'}),
  };
};

/// Ответ PostgREST на просроченный токен.
ResponseBody jwtExpired() => json(401, {'code': 'PGRST303', 'message': 'JWT expired'});

Dio dio(FakeServer server, {String? Function()? token, Future<void> Function()? refresh}) => buildDio(
  baseUrl: 'https://test.supabase.co',
  apiKey: 'sb_publishable_test',
  adapter: server,
  logging: false,
  retryDelay: Duration.zero,
  tokenProvider: token,
  refreshToken: refresh,
);

Future<AuthNotifier> notifier(FakeServer server, {DateTime Function()? clock}) async {
  final prefs = await SharedPreferences.getInstance();
  return AuthNotifier(prefs, AuthApi(dio(server)), clock: clock);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('вход: почта по логину, токены Supabase Auth, профиль из profiles', () async {
    final server = FakeServer(supabase('manager'));
    final auth = await notifier(server);
    await auth.login('manager', 'Manager#2026');

    expect(server.log, [loginEmail, signIn, profileCall]);
    expect(server.requests[1].data, {'email': 'manager@kinoteka.test', 'password': 'Manager#2026'});
    expect(server.requests[2].queryParameters['auth_id'], 'eq.uid-manager');

    final prefs = await SharedPreferences.getInstance();
    expect(auth.isAuthenticated, isTrue);
    expect(auth.role, Role.manager);
    expect(auth.user?.firstName, 'Алексей');
    expect(prefs.getString(AuthNotifier.kRefresh), 'refresh-1');
    expect(prefs.getString(AuthNotifier.kUser), contains('"role":"manager"'));
  });

  test('неверный пароль: понятное сообщение и ни одной попытки обновить токен', () async {
    final server = FakeServer(
      (o) => o.path == '/auth/v1/token'
          ? json(400, {'code': 400, 'error_code': 'invalid_credentials', 'msg': 'Invalid login credentials'})
          : supabase('admin')(o),
    );
    final auth = await notifier(server);

    await expectLater(
      auth.login('admin', 'плохой'),
      throwsA(isA<UnauthorizedException>().having((e) => e.message, 'message', 'Неверный логин или пароль.')),
    );
    expect(server.log, [loginEmail, signIn]);
    expect(auth.isAuthenticated, isFalse);
  });

  test('неизвестный логин: тот же ответ, до Supabase Auth запрос не доходит', () async {
    final server = FakeServer((o) => json(200, null));
    final auth = await notifier(server);

    await expectLater(
      auth.login('nobody', 'Pass#2026'),
      throwsA(isA<UnauthorizedException>().having((e) => e.message, 'message', 'Неверный логин или пароль.')),
    );
    expect(server.log, [loginEmail]);
  });

  test('заблокированный пользователь: отказ и отзыв выданной сессии', () async {
    final server = FakeServer(supabase('blocked', blocked: true));
    final auth = await notifier(server);

    await expectLater(
      auth.login('blocked', 'Blocked#2026'),
      throwsA(isA<ForbiddenException>().having((e) => e.message, 'message', contains('заблокирована'))),
    );
    expect(server.log.last, 'POST /auth/v1/logout');
    expect(server.requests.last.queryParameters['scope'], 'local');
    expect(auth.isAuthenticated, isFalse);
  });

  test('регистрация: сначала ошибки по полям из базы, данные формы — в метаданные', () async {
    final server = FakeServer(
      (o) => switch (o.path) {
        '/rest/v1/rpc/signup_errors' => json(200, <String, String>{}),
        '/auth/v1/signup' => json(200, session('newbie')),
        _ => supabase('newbie')(o),
      },
    );
    final auth = await notifier(server);
    await auth.register(
      username: ' Newbie ',
      password: 'Newbie#2026',
      firstName: 'Новый',
      lastName: 'Зритель',
      email: 'newbie@mail.ru',
    );

    expect(server.log, ['POST /rest/v1/rpc/signup_errors', 'POST /auth/v1/signup', profileCall]);
    final body = server.requests[1].data as Map;
    expect(body['email'], 'newbie@mail.ru');
    expect((body['data'] as Map)['username'], 'newbie');
    expect(auth.isAuthenticated, isTrue);
  });

  test('регистрация с занятым логином: ошибки по полям, Supabase Auth не вызывается', () async {
    final server = FakeServer((o) => json(200, {'username': 'Логин уже занят'}));
    final auth = await notifier(server);

    await expectLater(
      auth.register(username: 'admin', password: 'Admin#2026', firstName: 'А', lastName: 'Б', email: 'a@mail.ru'),
      throwsA(isA<ValidationException>().having((e) => e.errors['username'], 'username', 'Логин уже занят')),
    );
    expect(server.log, ['POST /rest/v1/rpc/signup_errors']);
  });

  test('401 на запрос данных: токен обновляется, запрос повторяется прозрачно', () async {
    final authServer = FakeServer(supabase('viewer'));
    final auth = await notifier(authServer);
    await auth.login('viewer', 'Viewer#2026');

    final api = FakeServer((o) {
      // База принимает только новый токен
      final ok = (o.headers['Authorization'] as String).endsWith('2');
      return ok ? json(200, []) : jwtExpired();
    });
    final client = dio(api, token: () => auth.accessToken, refresh: auth.refreshTokens);

    final r = await client.get<dynamic>('/rest/v1/movies_view');
    expect(r.statusCode, 200);
    expect(api.log, ['GET /rest/v1/movies_view', 'GET /rest/v1/movies_view']);
    expect(api.requests.last.headers['apikey'], 'sb_publishable_test');
    expect(authServer.count(refreshCall), 1);
    expect(auth.refreshCount, 1);
  });

  test('одновременные 401: токен обновляется один раз', () async {
    final authServer = FakeServer(supabase('viewer', refreshDelay: const Duration(milliseconds: 20)));
    final auth = await notifier(authServer);
    await auth.login('viewer', 'Viewer#2026');
    final api = FakeServer((o) => (o.headers['Authorization'] as String).endsWith('2') ? json(200, []) : jwtExpired());
    final client = dio(api, token: () => auth.accessToken, refresh: auth.refreshTokens);

    await Future.wait([
      client.get<dynamic>('/rest/v1/movies_view'),
      client.get<dynamic>('/rest/v1/genres'),
      client.get<dynamic>('/rest/v1/studios'),
    ]);
    expect(authServer.count(refreshCall), 1);
  });

  test('обновление не удалось: выход без зацикливания запросов', () async {
    final authServer = FakeServer(
      (o) => o.queryParameters['grant_type'] == 'refresh_token'
          ? json(400, {'code': 400, 'error_code': 'refresh_token_not_found', 'msg': 'Invalid Refresh Token'})
          : supabase('viewer')(o),
    );
    final auth = await notifier(authServer);
    await auth.login('viewer', 'Viewer#2026');
    final api = FakeServer((o) => jwtExpired());
    final client = dio(api, token: () => auth.accessToken, refresh: auth.refreshTokens);

    await expectLater(
      client.get<dynamic>('/rest/v1/movies_view'),
      throwsA(isA<DioException>().having((e) => e.error, 'error', isA<UnauthorizedException>())),
    );
    expect(api.log, hasLength(1), reason: 'исходный запрос не повторяется бесконечно');
    expect(authServer.count(refreshCall), 1);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.lastReason, LogoutReason.expired);
  });

  test('сессия восстанавливается после перезагрузки страницы', () async {
    final server = FakeServer(supabase('admin'));
    final first = await notifier(server);
    await first.login('admin', 'Admin#2026');

    // «Перезагрузка»: новый объект читает то же хранилище
    final second = await notifier(server);
    await second.restore();
    expect(second.isAuthenticated, isTrue);
    expect(second.role, Role.admin);
  });

  test('после долгой неактивности восстановления нет, причина сохраняется', () async {
    var now = DateTime(2026, 10, 27, 12);
    final server = FakeServer(supabase('viewer'));
    final first = await notifier(server, clock: () => now);
    await first.login('viewer', 'Viewer#2026');

    now = now.add(const Duration(minutes: 4));
    final second = await notifier(server, clock: () => now);
    await second.restore();
    expect(second.isAuthenticated, isFalse);
    expect(second.lastReason, LogoutReason.inactivity);
  });

  group('Защита маршрутов', () {
    test('без входа — на экран входа с адресом возврата', () async {
      final auth = await notifier(FakeServer((o) => json(500, null)));
      expect(authRedirect(auth, Uri.parse('/movies/7')), '/login?from=%2Fmovies%2F7');
      expect(authRedirect(auth, Uri.parse('/login')), isNull);
    });

    test('после входа — обратно на запомненный адрес', () async {
      final auth = await notifier(FakeServer(supabase('viewer')));
      await auth.login('viewer', 'Viewer#2026');
      expect(authRedirect(auth, Uri.parse('/login?from=%2Fmovies%2F7')), '/movies/7');
      expect(authRedirect(auth, Uri.parse('/login?from=%2F%2Fevil.example')), '/');
    });

    test('чужой раздел — экран отказа, свой — без перенаправления', () async {
      final auth = await notifier(FakeServer(supabase('viewer')));
      await auth.login('viewer', 'Viewer#2026');
      expect(authRedirect(auth, Uri.parse('/admin/users')), '/forbidden?from=%2Fadmin%2Fusers');
      expect(authRedirect(auth, Uri.parse('/movies/new')), startsWith('/forbidden'));
      expect(authRedirect(auth, Uri.parse('/my-card')), isNull);
      expect(authRedirect(auth, Uri.parse('/movies')), isNull);
    });
  });
}
