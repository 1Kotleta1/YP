import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../models/entity.dart';
import '../repositories/supabase_repository.dart' show asMap, camelKeys, parseRows, rpc;

/// Вход, регистрация, обновление токена и выход через Supabase Auth.
///
/// Supabase Auth выдаёт пару токенов: JWT доступа (по умолчанию на час)
/// и токен обновления. Роль, имя и блокировка хранятся не в токене,
/// а в таблице profiles: после входа профиль читается отдельным запросом.
///
/// Работает через отдельный Dio без интерсептора обновления токена:
/// ответ 400/401 на вход означает «неверный пароль», и пытаться
/// обновлять токен в ответ на него нельзя — получится бесконечный цикл.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// В приложении вход по логину, а Supabase Auth входит по почте:
  /// почта находится функцией login_email. Для неизвестного логина
  /// ответ тот же, что для неверного пароля.
  Future<AuthSession> login(String username, String password) => guard(() async {
    final email = await rpc(_dio, 'login_email', {'p_username': username.trim()});
    if (email is! String || email.isEmpty) throw const UnauthorizedException('Неверный логин или пароль.');
    final r = await _dio.post<dynamic>(
      '/auth/v1/token',
      queryParameters: {'grant_type': 'password'},
      data: {'email': email, 'password': password},
    );
    return _session(asMap(r.data));
  });

  /// Регистрация доступна всем и создаёт зрителя с новой картой: профиль,
  /// зрителя и карту создаёт триггер базы handle_new_user по данным формы.
  Future<AuthSession> register({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    required String email,
  }) => guard(() async {
    final form = {
      'username': username.trim().toLowerCase(),
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim(),
    };
    // Ошибки по полям — до обращения к Supabase Auth: иначе на занятый
    // логин он ответил бы общим «Database error saving new user»
    final errors = await rpc(_dio, 'signup_errors', {
      'p': {...form, 'password': password},
    });
    if (errors is Map && errors.isNotEmpty) {
      throw ValidationException('Ошибка валидации', errors.map((k, v) => MapEntry('$k', '$v')));
    }
    final r = await _dio.post<dynamic>(
      '/auth/v1/signup',
      data: {'email': form['email'], 'password': password, 'data': form},
    );
    final body = asMap(r.data);
    if (body['access_token'] == null) {
      throw const ConflictException(
        'Учётная запись создана, но войти нельзя: в Supabase включено подтверждение почты '
        '(Authentication → Sign In / Providers → Email → Confirm email).',
      );
    }
    return _session(body);
  });

  Future<AuthSession> refresh(String refreshToken) => guard(() async {
    final r = await _dio.post<dynamic>(
      '/auth/v1/token',
      queryParameters: {'grant_type': 'refresh_token'},
      data: {'refresh_token': refreshToken},
    );
    return _session(asMap(r.data));
  });

  /// Профиль вошедшего пользователя по токену доступа.
  Future<AppUser> me(String accessToken) => guard(() async {
    final r = await _dio.get<dynamic>(
      '/rest/v1/profiles',
      // Администратору правило RLS показывает все профили — нужен свой
      queryParameters: {'select': '*', 'auth_id': 'eq.${jwtSubject(accessToken)}'},
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final users = parseRows(r.data, (row) => AppUser.fromJson(camelKeys(row)));
    if (users.isEmpty) throw const UnauthorizedException('Профиль пользователя не найден. Войдите снова.');
    return users.first;
  });

  /// Отзыв сессии на сервере. Ошибки не важны: выход на клиенте
  /// выполняется в любом случае.
  ///
  /// scope=local — только эта сессия. По умолчанию Supabase Auth выходит
  /// глобально: выход по неактивности в одной вкладке завершил бы сессии
  /// пользователя на всех устройствах.
  Future<void> logout(String accessToken) async {
    try {
      await _dio.post<dynamic>(
        '/auth/v1/logout',
        queryParameters: {'scope': 'local'},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } catch (_) {}
  }

  /// Ответ Supabase Auth → пара токенов и профиль. Заблокированного
  /// пользователя сразу выводим: база всё равно не даст ему ни одной строки.
  Future<AuthSession> _session(Map<String, dynamic> body) async {
    final access = jsonString(body['access_token']);
    final refresh = jsonString(body['refresh_token']);
    final user = await me(access);
    if (user.blocked) {
      await logout(access);
      throw const ForbiddenException('Учётная запись заблокирована. Обратитесь к администратору.');
    }
    return AuthSession(accessToken: access, refreshToken: refresh, user: user);
  }
}

/// Идентификатор пользователя (sub) из полезной нагрузки JWT. Подпись
/// здесь не проверяется: это делает сервер при каждом запросе.
String jwtSubject(String token) {
  try {
    final payload = token.split('.')[1];
    final data = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload))));
    return data is Map ? jsonString(data['sub']) : '';
  } catch (_) {
    return '';
  }
}
