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

  int count(String path) => log.where((l) => l.endsWith(path)).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    log.add('${o.method} ${o.path}');
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

/// Токен с нужным сроком действия; подпись клиенту не важна.
String token(String role, DateTime exp, {String type = 'access'}) {
  String part(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'type': type, 'role': role, 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

Map<String, dynamic> session(String role, {String suffix = '1'}) => {
      'accessToken': token(role, DateTime.now().add(const Duration(minutes: 15))) + suffix,
      'refreshToken': 'refresh-$suffix',
      'user': {'id': 3, 'username': role, 'firstName': 'Алексей', 'lastName': 'Иванов', 'role': role},
    };

Dio dio(FakeServer server, {String? Function()? token, Future<void> Function()? refresh}) => buildDio(
      baseUrl: 'http://test/api',
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

  test('вход сохраняет токены и профиль в хранилище', () async {
    final server = FakeServer((o) => json(200, session('manager')));
    final auth = await notifier(server);
    await auth.login('manager', 'Manager#2026');

    final prefs = await SharedPreferences.getInstance();
    expect(auth.isAuthenticated, isTrue);
    expect(auth.role, Role.manager);
    expect(prefs.getString(AuthNotifier.kRefresh), 'refresh-1');
    expect(prefs.getString(AuthNotifier.kUser), contains('"role":"manager"'));
  });

  test('неверный пароль: понятное сообщение и ни одной попытки обновить токен', () async {
    final server = FakeServer((o) => json(401, {'message': 'Неверный логин или пароль.'}));
    final auth = await notifier(server);

    await expectLater(
      auth.login('admin', 'плохой'),
      throwsA(isA<UnauthorizedException>().having((e) => e.message, 'message', 'Неверный логин или пароль.')),
    );
    expect(server.log, ['POST /auth/login']);
    expect(auth.isAuthenticated, isFalse);
  });

  test('401 на запрос данных: токен обновляется, запрос повторяется прозрачно', () async {
    final authServer = FakeServer((o) => o.path == '/auth/login' ? json(200, session('viewer')) : json(200, session('viewer', suffix: '2')));
    final auth = await notifier(authServer);
    await auth.login('viewer', 'Viewer#2026');

    final api = FakeServer((o) {
      // Сервер принимает только новый токен
      final ok = (o.headers['Authorization'] as String).endsWith('2');
      return ok ? json(200, {'items': [], 'page': 1, 'size': 10, 'total': 0}) : json(401, {'message': 'Срок действия токена истёк.'});
    });
    final client = dio(api, token: () => auth.accessToken, refresh: auth.refreshTokens);

    final r = await client.get<dynamic>('/movies');
    expect(r.statusCode, 200);
    expect(api.log, ['GET /movies', 'GET /movies']);
    expect(authServer.count('/auth/refresh'), 1);
    expect(auth.refreshCount, 1);
  });

  test('одновременные 401: токен обновляется один раз', () async {
    final authServer = FakeServer((o) async {
      if (o.path == '/auth/refresh') await Future<void>.delayed(const Duration(milliseconds: 20));
      return json(200, session('viewer', suffix: o.path == '/auth/login' ? '1' : '2'));
    });
    final auth = await notifier(authServer);
    await auth.login('viewer', 'Viewer#2026');
    final api = FakeServer((o) => (o.headers['Authorization'] as String).endsWith('2')
        ? json(200, {'ok': true})
        : json(401, {'message': 'истёк'}));
    final client = dio(api, token: () => auth.accessToken, refresh: auth.refreshTokens);

    await Future.wait([client.get<dynamic>('/movies'), client.get<dynamic>('/genres'), client.get<dynamic>('/studios')]);
    expect(authServer.count('/auth/refresh'), 1);
  });

  test('обновление не удалось: выход без зацикливания запросов', () async {
    final authServer = FakeServer((o) => o.path == '/auth/login'
        ? json(200, session('viewer'))
        : json(401, {'message': 'Токен обновления отозван, войдите снова.'}));
    final auth = await notifier(authServer);
    await auth.login('viewer', 'Viewer#2026');
    final api = FakeServer((o) => json(401, {'message': 'Подпись токена неверна.'}));
    final client = dio(api, token: () => auth.accessToken, refresh: auth.refreshTokens);

    await expectLater(
      client.get<dynamic>('/movies'),
      throwsA(isA<DioException>().having((e) => e.error, 'error', isA<UnauthorizedException>())),
    );
    expect(api.count('/movies'), 1, reason: 'исходный запрос не повторяется бесконечно');
    expect(authServer.count('/auth/refresh'), 1);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.lastReason, LogoutReason.expired);
  });

  test('сессия восстанавливается после перезагрузки страницы', () async {
    final server = FakeServer((o) => json(200, session('admin')));
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
    final server = FakeServer((o) => json(200, session('viewer')));
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
      final auth = await notifier(FakeServer((o) => json(200, session('viewer'))));
      await auth.login('viewer', 'Viewer#2026');
      expect(authRedirect(auth, Uri.parse('/login?from=%2Fmovies%2F7')), '/movies/7');
      expect(authRedirect(auth, Uri.parse('/login?from=%2F%2Fevil.example')), '/');
    });

    test('чужой раздел — экран отказа, свой — без перенаправления', () async {
      final auth = await notifier(FakeServer((o) => json(200, session('viewer'))));
      await auth.login('viewer', 'Viewer#2026');
      expect(authRedirect(auth, Uri.parse('/admin/users')), '/forbidden?from=%2Fadmin%2Fusers');
      expect(authRedirect(auth, Uri.parse('/movies/new')), startsWith('/forbidden'));
      expect(authRedirect(auth, Uri.parse('/my-card')), isNull);
      expect(authRedirect(auth, Uri.parse('/movies')), isNull);
    });
  });
}
